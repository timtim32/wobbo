extends RefCounted
## Which focus links the app may open (go-to-session D4). Pure.
##
## A focus link comes from a local agent adapter; only schemes of known agent
## hosts are opened, never file:, http(s): or anything else.

const ALLOWED_SCHEMES: Array[String] = ["claude"]


static func allowed(url: String) -> bool:
	var colon := url.find(":")
	if colon <= 0:
		return false
	return url.substr(0, colon).to_lower() in ALLOWED_SCHEMES
