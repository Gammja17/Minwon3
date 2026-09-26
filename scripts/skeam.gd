class_name Skeam
## SKEAM(KING 동아리 게임 상점) 도전 과제. 웹판이 SKEAM 안에서 돌 때만 알린다.
## SDK 는 export_presets.cfg 의 html/head_include 가 index.html 머리에 넣는다.
## 이름과 설명은 SKEAM game.yml 에 적는다 (docs/skeam.md, id 가 같아야 한다).
## 같은 과제를 또 알려도 SKEAM 은 한 번만 센다.

## 이야기 민원의 결과 플래그 -> 도전 과제
const FLAGS := {
	"dalsu_served": "dalsu_served",
	"scam_caught": "scam_caught",
	"taemin_caught": "taemin_caught",
	"envelope_refused": "envelope_refused",
	"councilor_refused": "councilor_refused",
	"audit_pass": "audit_pass",
	"minjae_saved": "minjae_saved",
	"haneul_ok": "haneul_ok",
	"jaehyuk_ok": "jaehyuk_ok",
	"doyun_done": "doyun_done",
}


static func unlock(id: String) -> void:
	if Game.tutorial and id != "tut_done":
		return   # 연습 창구에서 한 일은 세지 않는다
	if Engine.has_meta("skeam_log"):
		Engine.get_meta("skeam_log").append(id)   # 테스트용
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.SKEAM && SKEAM.unlock('%s')" % id)
