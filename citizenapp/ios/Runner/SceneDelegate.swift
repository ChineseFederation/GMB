import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  /// iOS 13+ 的钱包回跳进入 Scene。命中专用地址时只恢复当前界面；其他 URL 仍交给
  /// FlutterSceneDelegate，避免 WalletConnect 回跳被 MaterialApp 当成页面路由。
  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    if URLContexts.contains(where: { AppDelegate.isWalletConnectCallback($0.url) }) {
      return
    }
    super.scene(scene, openURLContexts: URLContexts)
  }
}
