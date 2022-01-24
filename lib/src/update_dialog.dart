import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:upgrade_util/upgrade_util.dart';

/// @Describe: Upgrade dialog
///
/// @Author: LiWeNHuI
/// @Date: 2022/1/12

/// Listener - Download progress
typedef DownloadProgressCallback = Function(int count, int total);

/// Listener - Download status
typedef DownloadStatusCallback = Function(DownloadStatus downloadStatus,
    {dynamic error});

class UpgradeDialog extends StatefulWidget {
  UpgradeDialog({
    Key? key,
    required this.appKey,
    required this.androidMarket,
    this.otherMarkets,
    required this.downloadUrl,
    this.saveApkName,
    this.savePrefixName,
    required this.title,
    required this.content,
    required this.contentTextAlign,
    this.scrollController,
    this.actionScrollController,
    required this.force,
    this.updateKey,
    required this.updateText,
    this.updateTextStyle,
    required this.isUpgradeDefaultAction,
    required this.isUpgradeDestructiveAction,
    this.cancelKey,
    required this.cancelText,
    this.cancelTextStyle,
    required this.isCancelDefaultAction,
    required this.isCancelDestructiveAction,
    this.updateCallback,
    this.cancelCallback,
    this.downloadProgressCallback,
    this.downloadStatusCallback,
    required this.androidTitle,
    required this.androidCancel,
    required this.downloadTip,
  })  : assert(appKey.isNotEmpty),
        super(key: key);

  static Future<T?> show<T>(
    BuildContext context, {
    Key? key,
    required String appKey,
    AndroidMarket? androidMarket,
    List<String>? otherMarkets,
    String? downloadUrl,
    String? saveApkName,
    String? savePrefixName,
    String? title,
    String? content,
    TextAlign contentTextAlign = TextAlign.start,
    ScrollController? scrollController,
    ScrollController? actionScrollController,
    bool force = false,
    Key? updateKey,
    String? updateText,
    TextStyle? updateTextStyle,
    bool isUpgradeDefaultAction = false,
    bool isUpgradeDestructiveAction = false,
    Key? cancelKey,
    String? cancelText,
    TextStyle? cancelTextStyle,
    bool isCancelDefaultAction = false,
    bool isCancelDestructiveAction = true,
    VoidCallback? updateCallback,
    VoidCallback? cancelCallback,
    DownloadProgressCallback? downloadProgressCallback,
    DownloadStatusCallback? downloadStatusCallback,
  }) async {
    if (!(Platform.isIOS || Platform.isAndroid)) {
      throw 'Unsupported platform.';
    }

    final local = UpgradeLocalizations.of(context);

    Widget child = UpgradeDialog(
      key: key ?? ObjectKey(context),
      appKey: appKey,
      androidMarket: androidMarket ?? AndroidMarket(),
      otherMarkets: otherMarkets,
      downloadUrl: downloadUrl ?? '',
      saveApkName: saveApkName,
      savePrefixName: savePrefixName,
      title: title ?? local.title,
      content: content ?? local.content,
      contentTextAlign: contentTextAlign,
      scrollController: scrollController,
      actionScrollController: actionScrollController,
      force: force,
      updateKey: updateKey,
      updateText: updateText ?? local.updateText,
      updateTextStyle: updateTextStyle,
      isUpgradeDefaultAction: isUpgradeDefaultAction,
      isUpgradeDestructiveAction: isUpgradeDestructiveAction,
      cancelKey: cancelKey,
      cancelText: cancelText ?? local.cancelText,
      cancelTextStyle: cancelTextStyle,
      isCancelDefaultAction: isCancelDefaultAction,
      isCancelDestructiveAction: isCancelDestructiveAction,
      updateCallback: updateCallback,
      cancelCallback: cancelCallback,
      downloadProgressCallback: downloadProgressCallback,
      downloadStatusCallback: downloadStatusCallback,
      androidTitle: local.androidTitle,
      androidCancel: local.androidCencel,
      downloadTip: local.downloadTip,
    );

    child = WillPopScope(child: child, onWillPop: () async => false);

    return showCupertinoDialog(context: context, builder: (ctx) => child);
  }

  @override
  _UpgradeDialogState createState() => _UpgradeDialogState();

  /// On Android platform, The [appKey] is the package name.
  /// On iOS platform, The [appKey] is App Store ID.
  /// It is required.
  final String appKey;

  /// The [androidMarket] is the settings of app market for Android.
  ///
  /// It is all false by default.
  final AndroidMarket androidMarket;

  /// Package name for markets other than presets.
  final List<String>? otherMarkets;

  /// The [downloadUrl] is a link of download for Apk.
  final String downloadUrl;

  /// They are the saved information after the apk download is completed. For details, see the [AndroidUtil.getDownloadPath] method.
  final String? saveApkName;
  final String? savePrefixName;

  final String title;

  final String content;

  /// The [contentTextAlign] is how to align text horizontally of [content].
  /// It is `TextAlign.start` by default.
  final TextAlign contentTextAlign;

  final ScrollController? scrollController;
  final ScrollController? actionScrollController;

  /// The [force] is Whether to force the update, there is no cancel button when forced.
  /// It is `false` by default.
  final bool force;

  final Key? updateKey;
  final String updateText;
  final TextStyle? updateTextStyle;
  final bool isUpgradeDefaultAction;
  final bool isUpgradeDestructiveAction;
  final Key? cancelKey;
  final String cancelText;
  final TextStyle? cancelTextStyle;
  final bool isCancelDefaultAction;
  final bool isCancelDestructiveAction;

  /// Use [updateCallback] to implement the event listener of clicking the update button.
  /// It is to close the dialog and open App Store and then jump to the details page of the app with application number [appId] by default.
  final VoidCallback? updateCallback;

  /// Use [cancelCallback] to implement the event listener of clicking the cancel button.
  /// It is to close the dialog by default.
  final VoidCallback? cancelCallback;

  /// Use [downloadProgressCallback] to realize the listening event of download progress.
  final DownloadProgressCallback? downloadProgressCallback;

  /// Use [downloadStatusCallback] to realize the listening event of download status.
  final DownloadStatusCallback? downloadStatusCallback;

  final String androidTitle;
  final String androidCancel;
  final String downloadTip;
}

class _UpgradeDialogState extends State<UpgradeDialog> {
  /// Download progress
  double _downloadProgress = 0.0;

  DownloadStatus _downloadStatus = DownloadStatus.none;

  bool _isShowProgress = false;

  final _cancelToken = CancelToken();

  @override
  void dispose() {
    super.dispose();

    _cancelToken.cancel('Page closed.');
  }

  @override
  Widget build(BuildContext context) {
    final cancelAction = CupertinoDialogAction(
      key: widget.cancelKey,
      onPressed: _cancel,
      isDestructiveAction: widget.isCancelDestructiveAction,
      isDefaultAction: widget.isCancelDefaultAction,
      textStyle: widget.cancelTextStyle,
      child: Text(widget.cancelText),
    );

    final updateAction = CupertinoDialogAction(
      key: widget.updateKey,
      onPressed: _update,
      isDefaultAction: force ? force : widget.isUpgradeDefaultAction,
      isDestructiveAction: widget.isUpgradeDestructiveAction,
      textStyle: widget.updateTextStyle,
      child: Text(widget.updateText),
    );

    final baseActions = <Widget>[
      if (!force) cancelAction,
      if (_isShowProgress)
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 45.0),
          child: const Center(child: CupertinoActivityIndicator()),
        )
      else
        updateAction,
    ];

    final downloadActions = <Widget>[
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 15.0),
        child: Material(
          color: Colors.transparent,
          child: Column(
            children: [
              Text(widget.downloadTip),
              const SizedBox(height: 8.0),
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 4.0),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(2)}%',
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12.0,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 14.0),
              Ink(
                width: double.infinity,
                height: 36.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFDEDEDE),
                  borderRadius: BorderRadius.circular(18.0),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18.0),
                  child: Center(child: Text(widget.androidCancel)),
                  onTap: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    ];

    final actions = _downloadProgress > 0 ? downloadActions : baseActions;

    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Text(widget.content, textAlign: widget.contentTextAlign),
      scrollController: widget.scrollController,
      actionScrollController: widget.actionScrollController,
      actions: actions,
    );
  }

  void _cancel() {
    cancelCallback?.call();

    Navigator.pop(context);
  }

  Future _update() async {
    updateCallback?.call();

    if (Platform.isIOS) {
      await _iosUpgrade();
    } else if (Platform.isAndroid) {
      await _androidUpgrade();
    }
  }

  Future _iosUpgrade() async {
    Navigator.pop(context);
    const e = EIOSJumpMode.detailPage;
    await IOSUpgradeUtil.jumpToAppStore(eIOSJumpMode: e, appId: widget.appKey);
  }

  Future _androidUpgrade() async {
    setState(() {
      if (mounted) {
        _isShowProgress = true;
      }
    });

    final markets = await AndroidUtil.getAvailableMarket(
      androidMarket: widget.androidMarket,
      otherMarkets: widget.otherMarkets,
    );

    setState(() {
      if (mounted) {
        _isShowProgress = false;
      }
    });

    if (markets.isEmpty) {
      if (widget.downloadUrl.isNotEmpty) {
        await _download();
      } else {
        throw 'Both [androidMarket] and [downloadUrl] are empty';
      }
    } else {
      if (markets.length == 1) {
        await _jumpToMarket(markets.first.packageNameD);
      } else if (markets.length > 1) {
        await _chooseMarkets(markets);
      }
    }
  }

  /// Choose Market
  Future _chooseMarkets(List<AndroidMarketModel> markets) async {
    showModalBottomSheet<void>(
      context: context,
      barrierColor:
          CupertinoDynamicColor.resolve(kCupertinoModalBarrierColor, context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14.0))),
      builder: (ctx) {
        final radius = BorderRadius.circular(24.0);
        const color = Color(0xFFDEDEDE);

        Widget child = InkWell(
          borderRadius: radius,
          child: Center(child: Text(widget.androidCancel)),
          onTap: () => Navigator.pop(ctx),
        );

        child = Ink(
          width: double.infinity,
          height: 48.0,
          decoration: BoxDecoration(color: color, borderRadius: radius),
          child: child,
        );

        child = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.androidTitle, style: const TextStyle(fontSize: 20.0)),
            const SizedBox(height: 10.0),
            Flexible(
              child: GridView.builder(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: markets.length,
                itemBuilder: (ctx, index) {
                  Widget child = AndroidView(
                    viewType: 'plugins.upgrade_util/view',
                    creationParams: markets[index].packageName,
                    creationParamsCodec: const StandardMessageCodec(),
                    hitTestBehavior: PlatformViewHitTestBehavior.transparent,
                  );

                  child = ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxWidth: 48.0, maxHeight: 48.0),
                    child: child,
                  );

                  child = Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [child, Text(markets[index].showNameD)],
                  );

                  child =
                      Padding(padding: const EdgeInsets.all(5.0), child: child);

                  return GestureDetector(
                    onTap: () async {
                      Navigator.pop(context);
                      await _jumpToMarket(markets[index].packageNameD);
                    },
                    child: child,
                  );
                },
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 0,
                  crossAxisSpacing: 0,
                  childAspectRatio: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 10.0),
            child,
          ],
        );

        return Padding(padding: const EdgeInsets.all(15.0), child: child);
      },
    );
  }

  Future _jumpToMarket(String marketPackageName) async {
    print(marketPackageName);

    Navigator.pop(context);
    await AndroidUtil.jumpToMarket(
      packageName: widget.appKey,
      marketPackageName: marketPackageName,
    );
  }

  Future _download() async {
    if (_downloadStatus == DownloadStatus.start ||
        _downloadStatus == DownloadStatus.downloading ||
        _downloadStatus == DownloadStatus.done) {
      debugPrint(
          'Current download status: $_downloadStatus, the download cannot be repeated.');
      return;
    }

    _updateStatus(DownloadStatus.start);

    try {
      final urlPath = widget.downloadUrl;
      final savePath = await AndroidUtil.getDownloadPath(
        apkName: widget.saveApkName,
        prefixName: widget.savePrefixName,
      );

      final dio = Dio();
      await dio.download(
        urlPath,
        savePath,
        cancelToken: _cancelToken,
        onReceiveProgress: (count, total) async {
          if (total == -1) {
            _updateProgress(0.01);
          } else {
            widget.downloadProgressCallback?.call(count, total);
            _updateProgress(count / total.toDouble());
          }

          if (_downloadProgress == 1) {
            // After downloading, jump to the program installation interface.
            _updateStatus(DownloadStatus.done);
            Navigator.pop(context);
            await AndroidUtil.installApk(savePath);
          } else {
            _updateStatus(DownloadStatus.downloading);
          }
        },
      );
    } catch (e) {
      debugPrint('$e');
      _updateProgress(0);
      _updateStatus(DownloadStatus.error, error: e);
    }
  }

  void _updateProgress(double value) {
    setState(() {
      if (mounted) {
        _downloadProgress = value;
      }
    });
  }

  void _updateStatus(DownloadStatus downloadStatus, {dynamic error}) {
    _downloadStatus = downloadStatus;
    widget.downloadStatusCallback?.call(_downloadStatus, error: error);
  }

  bool get force => widget.force;

  VoidCallback? get cancelCallback => widget.cancelCallback;

  VoidCallback? get updateCallback => widget.updateCallback;
}