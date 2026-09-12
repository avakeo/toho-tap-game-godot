extends Node
# 動画リワード広告の汎用マネージャ(autoload: AdManager)
# 用途(ガチャ/Lv upなど)は placement 文字列で区別するだけで、呼び出し側は
#   AdManager.show_rewarded("gacha", func(success: bool) -> void: ...)
# と書けばよい。ロード・視聴後の再ロード・失敗時のリトライは内部で行う。
# 強制表示のインタースティシャル広告は
#   AdManager.show_interstitial(func() -> void: ...)
# で、閉じられた(または表示できなかった)ときにコールバックが呼ばれる。
# 画面下のバナーは show_banner()/hide_banner() で出し入れし、高さは
# banner_height_changed(高さ[物理px]) で通知する(UIをバナー分だけ避けるために使う)。
# エディタやPC実行では AdMob プラグインが存在しないため、擬似視聴モードで
# 即座に成功を返す(ゲームロジック側の開発・検証用)。

# 報酬が確定した(=最後まで視聴した)ときに placement 付きで通知
signal rewarded(placement: String)
# 広告の準備状態が変わったときに通知(ボタンの活性化などに使う)
signal availability_changed(available: bool)
# バナーの表示高さ(物理px)が変わったときに通知。非表示・失敗時は 0
signal banner_height_changed(height_px: int)

# 本番の広告ユニットID。リリースビルドでのみ使う。
# placementごとにユニットIDを分けたくなったら値を Dictionary にして拡張する。
const AD_UNIT_IDS := {
	"Android": "",  # Android版リリース時に設定する
	"iOS": "ca-app-pub-7401497687267095/6072375289",
}
const INTERSTITIAL_UNIT_IDS := {
	"Android": "",  # Android版リリース時に設定する
	"iOS": "ca-app-pub-7401497687267095/3172989013",
}
const BANNER_UNIT_IDS := {
	"Android": "",  # Android版リリース時に設定する
	"iOS": "ca-app-pub-7401497687267095/6505371547",
}
# Google公式のテスト用ユニットID。デバッグビルド、または本番IDが未設定のときに使う。
# 本番ユニットは作成直後 No fill になりやすいので、開発中はこちらで動作確認する。
const TEST_AD_UNIT_IDS := {
	"Android": "ca-app-pub-3940256099942544/5224354917",
	"iOS": "ca-app-pub-3940256099942544/1712485313",
}
const TEST_INTERSTITIAL_UNIT_IDS := {
	"Android": "ca-app-pub-3940256099942544/1033173712",
	"iOS": "ca-app-pub-3940256099942544/4411468910",
}
const TEST_BANNER_UNIT_IDS := {
	"Android": "ca-app-pub-3940256099942544/6300978111",
	"iOS": "ca-app-pub-3940256099942544/2934735716",
}
const MAX_LOAD_RETRY := 5
# 擬似視聴モードで成功を返すまでの秒数
const FAKE_WATCH_SECONDS := 0.5
# 擬似モードで想定するバナー高さ(画面高に対する比率)。実機のアダプティブバナー相当
const FAKE_BANNER_HEIGHT_RATIO := 0.07

var _rewarded_ad: RewardedAd
var _is_loading := false
var _retry_count := 0
var _interstitial_ad: InterstitialAd
var _is_loading_interstitial := false
var _interstitial_retry_count := 0
var _banner: AdView
var _banner_visible := false
# ネイティブプラグインが使える環境か(Android/iOSの実機ビルドのみtrue)
var _plugin_available := false
# プラグインが無い環境で擬似視聴を許可するか(エディタ・PCのみ)
var _fake_mode := false

func _ready() -> void:
	_plugin_available = Engine.has_singleton("PoingGodotAdMob")
	if _plugin_available:
		MobileAds.initialize()
		_load_ad()
		_load_interstitial()
	else:
		# 実機以外は擬似モード。モバイル実機でプラグインが無い場合は
		# 導入ミスに気付けるよう擬似モードにはしない(常に利用不可)
		_fake_mode = OS.has_feature("editor") or OS.get_name() in ["Windows", "macOS", "Linux"]

# エディタ・PCの擬似モードか(バナーのプレースホルダー表示などに使う)
func is_fake_mode() -> bool:
	return _fake_mode

# 広告を表示できる状態か。リワードボタンの表示/活性の判定に使う
func is_ready() -> bool:
	return _fake_mode or _rewarded_ad != null

# 動画リワードを表示する。視聴完了で on_result.call(true)、
# 途中で閉じた・表示に失敗した場合は on_result.call(false) が呼ばれる。
func show_rewarded(placement: String, on_result: Callable = Callable()) -> void:
	if _fake_mode:
		await get_tree().create_timer(FAKE_WATCH_SECONDS).timeout
		print("AdManager: 擬似リワード視聴完了 placement=", placement)
		_finish(placement, true, on_result)
		return
	if _rewarded_ad == null:
		_finish(placement, false, on_result)
		_load_ad()
		return

	var ad := _rewarded_ad
	_rewarded_ad = null
	availability_changed.emit(false)
	var outcome := {"earned": false}

	var reward_listener := OnUserEarnedRewardListener.new()
	reward_listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		outcome.earned = true

	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_finish(placement, outcome.earned, on_result)
		_load_ad()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("AdManager: 表示失敗 " + str(error.message))
		ad.destroy()
		_finish(placement, false, on_result)
		_load_ad()

	ad.show(reward_listener)

func _finish(placement: String, success: bool, on_result: Callable) -> void:
	if success:
		rewarded.emit(placement)
	if on_result.is_valid():
		on_result.call(success)

# 使うユニットIDを決める。デバッグビルドや本番IDが空のときはテストIDにフォールバック
func _resolve_unit_id(production: Dictionary, test: Dictionary) -> String:
	var os_name := OS.get_name()
	var prod_id: String = production.get(os_name, "")
	if OS.is_debug_build() or prod_id.is_empty():
		return test.get(os_name, "")
	return prod_id

func _load_ad() -> void:
	if _is_loading or _rewarded_ad != null:
		return
	var unit_id := _resolve_unit_id(AD_UNIT_IDS, TEST_AD_UNIT_IDS)
	if unit_id.is_empty():
		return
	_is_loading = true

	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_is_loading = false
		_retry_count = 0
		_rewarded_ad = ad
		availability_changed.emit(true)
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_is_loading = false
		push_warning("AdManager: ロード失敗 " + str(error.message))
		_retry_load()

	RewardedAdLoader.new().load(unit_id, AdRequest.new(), callback)

# ロード失敗時は指数バックオフ(2,4,8...秒)で再試行する
func _retry_load() -> void:
	if _retry_count >= MAX_LOAD_RETRY:
		return
	_retry_count += 1
	await get_tree().create_timer(pow(2.0, _retry_count)).timeout
	_load_ad()

# インタースティシャル広告を表示する。閉じられた・表示できなかった、どちらの場合も
# on_closed が呼ばれるので、呼び出し側はゲーム進行をそこに続ければよい。
func show_interstitial(on_closed: Callable = Callable()) -> void:
	if _fake_mode:
		await get_tree().create_timer(FAKE_WATCH_SECONDS).timeout
		print("AdManager: 擬似インタースティシャル表示完了")
		_call_if_valid(on_closed)
		return
	if _interstitial_ad == null:
		_call_if_valid(on_closed)
		_load_interstitial()
		return

	var ad := _interstitial_ad
	_interstitial_ad = null
	ad.full_screen_content_callback.on_ad_dismissed_full_screen_content = func() -> void:
		ad.destroy()
		_call_if_valid(on_closed)
		_load_interstitial()
	ad.full_screen_content_callback.on_ad_failed_to_show_full_screen_content = func(error: AdError) -> void:
		push_warning("AdManager: インタースティシャル表示失敗 " + str(error.message))
		ad.destroy()
		_call_if_valid(on_closed)
		_load_interstitial()
	ad.show()

func _call_if_valid(callback: Callable) -> void:
	if callback.is_valid():
		callback.call()

func _load_interstitial() -> void:
	if _is_loading_interstitial or _interstitial_ad != null:
		return
	var unit_id := _resolve_unit_id(INTERSTITIAL_UNIT_IDS, TEST_INTERSTITIAL_UNIT_IDS)
	if unit_id.is_empty():
		return
	_is_loading_interstitial = true

	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_is_loading_interstitial = false
		_interstitial_retry_count = 0
		_interstitial_ad = ad
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_is_loading_interstitial = false
		push_warning("AdManager: インタースティシャルロード失敗 " + str(error.message))
		if _interstitial_retry_count >= MAX_LOAD_RETRY:
			return
		_interstitial_retry_count += 1
		await get_tree().create_timer(pow(2.0, _interstitial_retry_count)).timeout
		_load_interstitial()

	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), callback)

# 画面下にアダプティブバナーを表示する。ロード完了後に banner_height_changed を発火する
func show_banner() -> void:
	_banner_visible = true
	if _fake_mode:
		# エディタ・PCでもレイアウト確認できるよう、バナー相当の高さだけ通知する
		banner_height_changed.emit(int(DisplayServer.window_get_size().y * FAKE_BANNER_HEIGHT_RATIO))
		return
	if not _plugin_available:
		return
	if _banner != null:
		_banner.show()
		banner_height_changed.emit(_banner.get_height_in_pixels())
		return
	var unit_id := _resolve_unit_id(BANNER_UNIT_IDS, TEST_BANNER_UNIT_IDS)
	if unit_id.is_empty():
		return
	var size := AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	var view := AdView.new(unit_id, size, AdPosition.Values.BOTTOM)
	var listener := AdListener.new()
	listener.on_ad_loaded = func() -> void:
		if not _banner_visible:
			view.hide()
			return
		banner_height_changed.emit(view.get_height_in_pixels())
	listener.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		push_warning("AdManager: バナーロード失敗 " + str(error.message))
		banner_height_changed.emit(0)
	view.ad_listener = listener
	_banner = view
	view.load_ad(AdRequest.new())

func hide_banner() -> void:
	_banner_visible = false
	if _banner != null:
		_banner.hide()
	banner_height_changed.emit(0)
