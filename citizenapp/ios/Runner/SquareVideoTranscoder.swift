@preconcurrency import AVFoundation
import CoreMedia
import Foundation
import UIKit
import VideoToolbox

/// iOS 广场 HEVC 转码器；只调用 VideoToolbox 硬件路径，不引入软件编码器。
final class SquareVideoTranscoder {
  private let lock = NSLock()
  private var task: Task<Void, Never>?
  private var reader: AVAssetReader?
  private var writer: AVAssetWriter?

  func capabilities() -> [String: Bool] {
    [
      "can_encode_hevc": Self.supportsHardwareHevcEncoding(),
      "can_decode_hevc": VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC),
    ]
  }

  /// 通过实际创建“只允许硬件”的 VideoToolbox 会话探测能力，避免把软件回退误报为可用。
  private static func supportsHardwareHevcEncoding() -> Bool {
    var session: VTCompressionSession?
    let specification = [
      "RequireHardwareAcceleratedVideoEncoder": true,
    ] as CFDictionary
    let status = VTCompressionSessionCreate(
      allocator: kCFAllocatorDefault,
      width: 64,
      height: 64,
      codecType: kCMVideoCodecType_HEVC,
      encoderSpecification: specification,
      imageBufferAttributes: nil,
      compressedDataAllocator: nil,
      outputCallback: nil,
      refcon: nil,
      compressionSessionOut: &session
    )
    if let session {
      VTCompressionSessionInvalidate(session)
    }
    return status == noErr && session != nil
  }

  func cancel() {
    lock.lock()
    let currentTask = task
    let currentReader = reader
    let currentWriter = writer
    task = nil
    reader = nil
    writer = nil
    lock.unlock()
    currentTask?.cancel()
    currentReader?.cancelReading()
    currentWriter?.cancelWriting()
  }

  func transcode(
    _ request: SquareVideoRequest,
    completion: @escaping (Result<[String: Any], Error>) -> Void
  ) {
    lock.lock()
    guard task == nil else {
      lock.unlock()
      completion(.failure(SquareMediaError.processing("已有视频正在处理")))
      return
    }
    let newTask = Task {
      do {
        let value = try await run(request)
        finishTask()
        completion(.success(value))
      } catch {
        try? FileManager.default.removeItem(atPath: request.outputPath)
        try? FileManager.default.removeItem(atPath: request.coverPath)
        finishTask()
        completion(.failure(error))
      }
    }
    task = newTask
    lock.unlock()
  }

  private func finishTask() {
    lock.lock()
    task = nil
    reader = nil
    writer = nil
    lock.unlock()
  }

  private func run(_ request: SquareVideoRequest) async throws -> [String: Any] {
    guard Self.supportsHardwareHevcEncoding(),
          VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
    else {
      throw SquareMediaError.unsupported("当前设备不具备硬件 HEVC 编解码能力")
    }
    try Task.checkCancellation()
    let inputURL = URL(fileURLWithPath: request.inputPath)
    let outputURL = URL(fileURLWithPath: request.outputPath)
    let coverURL = URL(fileURLWithPath: request.coverPath)
    guard FileManager.default.fileExists(atPath: inputURL.path),
          inputURL.standardizedFileURL != outputURL.standardizedFileURL
    else {
      throw SquareMediaError.invalidRequest("输入视频不存在或输出路径覆盖原文件")
    }
    try? FileManager.default.removeItem(at: outputURL)
    try? FileManager.default.removeItem(at: coverURL)
    try FileManager.default.createDirectory(
      at: outputURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )

    let asset = AVURLAsset(url: inputURL)
    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
      throw SquareMediaError.invalidRequest("文件不包含视频轨")
    }
    let duration = try await asset.load(.duration)
    let durationSeconds = Int(ceil(duration.seconds))
    guard durationSeconds > 0, durationSeconds <= request.maxDurationSeconds else {
      throw SquareMediaError.invalidRequest("视频时长超出会员上限")
    }
    try await rejectHdrOrDolbyVision(videoTrack)

    let naturalSize = try await videoTrack.load(.naturalSize)
    let preferredTransform = try await videoTrack.load(.preferredTransform)
    let orientedRect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
    let sourceWidth = abs(orientedRect.width)
    let sourceHeight = abs(orientedRect.height)
    let targetSize = fitVideo(
      width: sourceWidth,
      height: sourceHeight,
      maxWidth: CGFloat(request.maxWidth),
      maxHeight: CGFloat(request.maxHeight)
    )
    let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
    let frameRate = max(1, min(Float(request.maxFrameRate), nominalFrameRate > 0 ? nominalFrameRate : 30))

    let videoComposition = AVMutableVideoComposition()
    videoComposition.renderSize = targetSize
    videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate.rounded()))
    let instruction = AVMutableVideoCompositionInstruction()
    instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
    let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
    var transform = preferredTransform
    transform = transform.concatenating(
      CGAffineTransform(translationX: -orientedRect.minX, y: -orientedRect.minY)
    )
    transform = transform.concatenating(
      CGAffineTransform(
        scaleX: targetSize.width / sourceWidth,
        y: targetSize.height / sourceHeight
      )
    )
    layerInstruction.setTransform(transform, at: .zero)
    instruction.layerInstructions = [layerInstruction]
    videoComposition.instructions = [instruction]

    let assetReader = try AVAssetReader(asset: asset)
    let videoOutput = AVAssetReaderVideoCompositionOutput(
      videoTracks: [videoTrack],
      videoSettings: [
        kCVPixelBufferPixelFormatTypeKey as String:
          kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
      ]
    )
    videoOutput.videoComposition = videoComposition
    videoOutput.alwaysCopiesSampleData = false
    guard assetReader.canAdd(videoOutput) else {
      throw SquareMediaError.processing("无法建立视频读取管线")
    }
    assetReader.add(videoOutput)

    let assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    assetWriter.shouldOptimizeForNetworkUse = true
    let videoInput = AVAssetWriterInput(
      mediaType: .video,
      outputSettings: [
        AVVideoCodecKey: AVVideoCodecType.hevc,
        AVVideoWidthKey: Int(targetSize.width),
        AVVideoHeightKey: Int(targetSize.height),
        AVVideoColorPropertiesKey: [
          AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
          AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
          AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
        ],
        AVVideoCompressionPropertiesKey: [
          AVVideoAverageBitRateKey: request.videoBitrate,
          AVVideoExpectedSourceFrameRateKey: Int(frameRate.rounded()),
          AVVideoMaxKeyFrameIntervalDurationKey: request.keyFrameIntervalSeconds,
          AVVideoAllowFrameReorderingKey: false,
          AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
        ],
      ]
    )
    videoInput.expectsMediaDataInRealTime = false
    guard assetWriter.canAdd(videoInput) else {
      throw SquareMediaError.processing("设备拒绝目标 HEVC Main 参数")
    }
    assetWriter.add(videoInput)

    var audioOutput: AVAssetReaderTrackOutput?
    var audioInput: AVAssetWriterInput?
    if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
      let output = AVAssetReaderTrackOutput(
        track: audioTrack,
        outputSettings: [
          AVFormatIDKey: kAudioFormatLinearPCM,
          AVSampleRateKey: request.audioSampleRate,
        ]
      )
      output.alwaysCopiesSampleData = false
      let input = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVEncoderBitRateKey: request.audioBitrate,
          AVSampleRateKey: request.audioSampleRate,
          AVNumberOfChannelsKey: 2,
        ]
      )
      guard assetReader.canAdd(output), assetWriter.canAdd(input) else {
        throw SquareMediaError.processing("无法建立 AAC-LC 音频管线")
      }
      assetReader.add(output)
      assetWriter.add(input)
      audioOutput = output
      audioInput = input
    }

    setActivePipeline(reader: assetReader, writer: assetWriter)
    guard assetWriter.startWriting(), assetReader.startReading() else {
      throw assetWriter.error ?? assetReader.error ?? SquareMediaError.processing("媒体管线启动失败")
    }
    assetWriter.startSession(atSourceTime: .zero)
    try await copySamples(
      reader: assetReader,
      writer: assetWriter,
      videoOutput: videoOutput,
      videoInput: videoInput,
      audioOutput: audioOutput,
      audioInput: audioInput
    )
    try Task.checkCancellation()
    try await createCover(
      asset: AVURLAsset(url: outputURL),
      destination: coverURL,
      maxEdge: request.coverMaxEdge
    )
    return try await inspectOutput(
      outputURL,
      coverURL: coverURL,
      request: request
    )
  }

  /// 隔离同步锁，避免在异步函数体内直接调用锁 API。
  private func setActivePipeline(reader: AVAssetReader, writer: AVAssetWriter) {
    lock.lock()
    self.reader = reader
    self.writer = writer
    lock.unlock()
  }

  private func copySamples(
    reader: AVAssetReader,
    writer: AVAssetWriter,
    videoOutput: AVAssetReaderOutput,
    videoInput: AVAssetWriterInput,
    audioOutput: AVAssetReaderOutput?,
    audioInput: AVAssetWriterInput?
  ) async throws {
    try await withCheckedThrowingContinuation {
      (continuation: CheckedContinuation<Void, Error>) in
      let group = DispatchGroup()
      let finishLock = NSLock()
      var firstError: Error?

      func pump(
        output: AVAssetReaderOutput,
        input: AVAssetWriterInput,
        queue: DispatchQueue
      ) {
        group.enter()
        var finished = false
        input.requestMediaDataWhenReady(on: queue) {
          guard !finished else { return }
          while input.isReadyForMoreMediaData {
            guard let sample = output.copyNextSampleBuffer() else {
              finished = true
              input.markAsFinished()
              group.leave()
              return
            }
            if !input.append(sample) {
              finished = true
              input.markAsFinished()
              finishLock.lock()
              firstError = firstError ?? writer.error ?? SquareMediaError.processing("写入媒体样本失败")
              finishLock.unlock()
              group.leave()
              return
            }
          }
        }
      }

      pump(
        output: videoOutput,
        input: videoInput,
        queue: DispatchQueue(label: "citizenapp.square_media.video")
      )
      if let audioOutput, let audioInput {
        pump(
          output: audioOutput,
          input: audioInput,
          queue: DispatchQueue(label: "citizenapp.square_media.audio")
        )
      }
      group.notify(queue: DispatchQueue.global(qos: .userInitiated)) {
        if let firstError {
          reader.cancelReading()
          writer.cancelWriting()
          continuation.resume(throwing: firstError)
          return
        }
        guard reader.status == .completed else {
          writer.cancelWriting()
          continuation.resume(
            throwing: reader.error ?? SquareMediaError.processing("读取媒体失败")
          )
          return
        }
        writer.finishWriting {
          if writer.status == .completed {
            continuation.resume()
          } else {
            continuation.resume(
              throwing: writer.error ?? SquareMediaError.processing("封装 MP4 失败")
            )
          }
        }
      }
    }
  }

  private func rejectHdrOrDolbyVision(_ track: AVAssetTrack) async throws {
    let descriptions = try await track.load(.formatDescriptions)
    for description in descriptions {
      let subtype = CMFormatDescriptionGetMediaSubType(description).fourCC
      if subtype == "dvh1" || subtype == "dvhe" {
        throw SquareMediaError.unsupported("禁止 Dolby Vision 视频")
      }
      guard let rawExtensions = CMFormatDescriptionGetExtensions(description) else {
        continue
      }
      let extensions = rawExtensions as NSDictionary
      let transfer = extensions[kCMFormatDescriptionExtension_TransferFunction] as? String
      if transfer == (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String) ||
          transfer == (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String)
      {
        throw SquareMediaError.unsupported("HDR 视频不允许发布，请先转为 SDR")
      }
    }
  }

  private func fitVideo(
    width: CGFloat,
    height: CGFloat,
    maxWidth: CGFloat,
    maxHeight: CGFloat
  ) -> CGSize {
    let boundWidth = height > width ? maxHeight : maxWidth
    let boundHeight = height > width ? maxWidth : maxHeight
    let scale = min(1, min(boundWidth / width, boundHeight / height))
    let outputWidth = max(2, floor(width * scale / 2) * 2)
    let outputHeight = max(2, floor(height * scale / 2) * 2)
    return CGSize(width: outputWidth, height: outputHeight)
  }

  private func createCover(asset: AVAsset, destination: URL, maxEdge: Int) async throws {
    let generator = AVAssetImageGenerator(asset: asset)
    generator.appliesPreferredTrackTransform = true
    generator.maximumSize = CGSize(width: maxEdge, height: maxEdge)
    let duration = try await asset.load(.duration)
    let coverTime = min(1, max(0, duration.seconds / 2))
    let image = try generator.copyCGImage(
      at: CMTime(seconds: coverTime, preferredTimescale: 600),
      actualTime: nil
    )
    guard let data = UIImage(cgImage: image).pngData(), !data.isEmpty else {
      throw SquareMediaError.processing("视频封面 PNG 编码失败")
    }
    try data.write(to: destination, options: .atomic)
  }

  private func inspectOutput(
    _ url: URL,
    coverURL: URL,
    request: SquareVideoRequest
  ) async throws -> [String: Any] {
    let byteSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
    let coverByteSize = try FileManager.default.attributesOfItem(atPath: coverURL.path)[.size] as? NSNumber
    guard let byteSize, byteSize.int64Value > 0, byteSize.int64Value <= request.maxBytes,
          let coverByteSize, coverByteSize.int64Value > 0
    else {
      throw SquareMediaError.processing("视频或封面文件大小不合法")
    }
    guard try isFastStart(url) else {
      throw SquareMediaError.processing("MP4 未满足 faststart")
    }
    let asset = AVURLAsset(url: url)
    guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
      throw SquareMediaError.processing("成品缺少视频轨")
    }
    let descriptions = try await videoTrack.load(.formatDescriptions)
    guard descriptions.count == 1,
          CMFormatDescriptionGetMediaSubType(descriptions[0]).fourCC == "hvc1"
    else {
      throw SquareMediaError.processing("视频 sample entry 不是 hvc1")
    }
    try await rejectHdrOrDolbyVision(videoTrack)
    if let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
      let audioDescriptions = try await audioTrack.load(.formatDescriptions)
      guard let description = audioDescriptions.first,
            CMFormatDescriptionGetMediaSubType(description) == kAudioFormatMPEG4AAC,
            let stream = CMAudioFormatDescriptionGetStreamBasicDescription(description),
            Int(stream.pointee.mSampleRate.rounded()) == request.audioSampleRate
      else {
        throw SquareMediaError.processing("音频不是 AAC-LC 48kHz")
      }
    }
    let duration = try await asset.load(.duration)
    let durationSeconds = Int(ceil(duration.seconds))
    let naturalSize = try await videoTrack.load(.naturalSize)
    let preferredTransform = try await videoTrack.load(.preferredTransform)
    let rect = CGRect(origin: .zero, size: naturalSize).applying(preferredTransform)
    let frameRate = try await videoTrack.load(.nominalFrameRate)
    let average = Int(Double(byteSize.int64Value * 8) / duration.seconds)
    let peak = try await peakBitrate(asset)
    return [
      "duration_seconds": durationSeconds,
      "width": Int(abs(rect.width)),
      "height": Int(abs(rect.height)),
      "frame_rate": Double(frameRate),
      "total_average_bitrate": average,
      "total_peak_bitrate": peak,
      "byte_size": byteSize.int64Value,
      "cover_byte_size": coverByteSize.int64Value,
      "video_codec": "hevc",
      "sample_entry": "hvc1",
      "fast_start": true,
      "is_sdr": true,
    ]
  }

  private func peakBitrate(_ asset: AVAsset) async throws -> Int {
    var buckets: [Int64: Int64] = [:]
    let videoTracks = try await asset.loadTracks(withMediaType: .video)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    for track in videoTracks + audioTracks {
      let reader = try AVAssetReader(asset: asset)
      let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
      guard reader.canAdd(output) else { continue }
      reader.add(output)
      guard reader.startReading() else { throw reader.error ?? SquareMediaError.processing("码率复核失败") }
      while let sample = output.copyNextSampleBuffer() {
        let second = Int64(CMSampleBufferGetPresentationTimeStamp(sample).seconds.rounded(.down))
        buckets[second, default: 0] += Int64(CMSampleBufferGetTotalSampleSize(sample) * 8)
      }
    }
    return Int(min(Int64(Int.max), buckets.values.max() ?? 0))
  }

  private func isFastStart(_ url: URL) throws -> Bool {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let fileSize = try handle.seekToEnd()
    var offset: UInt64 = 0
    var moovOffset: UInt64?
    var mdatOffset: UInt64?
    while offset + 8 <= fileSize {
      try handle.seek(toOffset: offset)
      guard let header = try handle.read(upToCount: 16), header.count >= 8 else { return false }
      let size32 = UInt64(header.uint32(at: 0))
      let type = String(data: header[4..<8], encoding: .ascii) ?? ""
      let atomSize: UInt64
      if size32 == 1 {
        guard header.count >= 16 else { return false }
        atomSize = header.uint64(at: 8)
      } else if size32 == 0 {
        atomSize = fileSize - offset
      } else {
        atomSize = size32
      }
      guard atomSize >= 8, offset + atomSize <= fileSize else { return false }
      if type == "moov" { moovOffset = offset }
      if type == "mdat" { mdatOffset = offset }
      offset += atomSize
    }
    guard let moovOffset, let mdatOffset else { return false }
    return moovOffset < mdatOffset
  }
}

private extension FourCharCode {
  var fourCC: String {
    let bytes: [UInt8] = [
      UInt8((self >> 24) & 0xff),
      UInt8((self >> 16) & 0xff),
      UInt8((self >> 8) & 0xff),
      UInt8(self & 0xff),
    ]
    return String(bytes: bytes, encoding: .ascii) ?? ""
  }
}

private extension Data {
  func uint32(at offset: Int) -> UInt32 {
    self[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
  }

  func uint64(at offset: Int) -> UInt64 {
    self[offset..<(offset + 8)].reduce(0) { ($0 << 8) | UInt64($1) }
  }
}
