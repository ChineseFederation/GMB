import Flutter
import Foundation

/// 公民广场媒体原生通道；跨端字段统一使用 snake_case。
final class SquareMediaChannel {
  static let channelName = "citizenapp/square_media"

  private let channel: FlutterMethodChannel
  private let transcoder = SquareVideoTranscoder()

  init(binaryMessenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  deinit {
    transcoder.cancel()
    channel.setMethodCallHandler(nil)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "capabilities":
      result(transcoder.capabilities())
    case "transcode_video":
      do {
        let request = try SquareVideoRequest(arguments: call.arguments)
        transcoder.transcode(request) { transcodeResult in
          DispatchQueue.main.async {
            switch transcodeResult {
            case let .success(value):
              result(value)
            case let .failure(error):
              result(
                FlutterError(
                  code: "square_media_transcode_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            }
          }
        }
      } catch {
        result(
          FlutterError(
            code: "square_media_invalid",
            message: error.localizedDescription,
            details: nil
          )
        )
      }
    case "cancel_video":
      transcoder.cancel()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}

struct SquareVideoRequest {
  let inputPath: String
  let outputPath: String
  let coverPath: String
  let maxWidth: Int
  let maxHeight: Int
  let videoBitrate: Int
  let totalPeakBitrate: Int
  let audioBitrate: Int
  let audioSampleRate: Int
  let maxFrameRate: Int
  let keyFrameIntervalSeconds: Int
  let maxDurationSeconds: Int
  let maxBytes: Int64
  let coverMaxEdge: Int
  let coverQuality: Int
  let coverMaxBytes: Int

  init(arguments: Any?) throws {
    guard let values = arguments as? [String: Any] else {
      throw SquareMediaError.invalidRequest("视频参数不是对象")
    }
    inputPath = try values.requiredString("input_path")
    outputPath = try values.requiredString("output_path")
    coverPath = try values.requiredString("cover_path")
    maxWidth = try values.requiredInt("max_width")
    maxHeight = try values.requiredInt("max_height")
    videoBitrate = try values.requiredInt("video_bitrate")
    totalPeakBitrate = try values.requiredInt("total_peak_bitrate")
    audioBitrate = try values.requiredInt("audio_bitrate")
    audioSampleRate = try values.requiredInt("audio_sample_rate")
    maxFrameRate = try values.requiredInt("max_frame_rate")
    keyFrameIntervalSeconds = try values.requiredInt("key_frame_interval_seconds")
    maxDurationSeconds = try values.requiredInt("max_duration_seconds")
    maxBytes = try values.requiredInt64("max_bytes")
    coverMaxEdge = try values.requiredInt("cover_max_edge")
    coverQuality = try values.requiredInt("cover_quality")
    coverMaxBytes = try values.requiredInt("cover_max_bytes")

    guard maxWidth >= 2, maxWidth <= 1920,
          maxHeight >= 2, maxHeight <= 1080,
          videoBitrate > 0, audioBitrate > 0, totalPeakBitrate > 0,
          audioSampleRate == 48_000,
          maxFrameRate > 0, maxFrameRate <= 30,
          keyFrameIntervalSeconds == 2,
          maxDurationSeconds > 0, maxDurationSeconds <= 10_800,
          maxBytes > 0, maxBytes <= 3_000_000_000,
          coverMaxEdge > 0, coverMaxEdge <= 720,
          coverQuality > 0, coverQuality <= 100,
          coverMaxBytes > 0, coverMaxBytes <= 512_000
    else {
      throw SquareMediaError.invalidRequest("视频参数超出允许范围")
    }
  }
}

enum SquareMediaError: LocalizedError {
  case invalidRequest(String)
  case unsupported(String)
  case processing(String)
  case cancelled

  var errorDescription: String? {
    switch self {
    case let .invalidRequest(message), let .unsupported(message), let .processing(message):
      return message
    case .cancelled:
      return "视频处理已取消"
    }
  }
}

private extension Dictionary where Key == String, Value == Any {
  func requiredString(_ key: String) throws -> String {
    guard let value = self[key] as? String, !value.isEmpty else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return value
  }

  func requiredInt(_ key: String) throws -> Int {
    guard let number = self[key] as? NSNumber else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return number.intValue
  }

  func requiredInt64(_ key: String) throws -> Int64 {
    guard let number = self[key] as? NSNumber else {
      throw SquareMediaError.invalidRequest("\(key) 缺失")
    }
    return number.int64Value
  }
}
