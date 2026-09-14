function parseReceivers(text) {
  if (!text) return []
  try {
    var parsed = JSON.parse(text)
    if (!Array.isArray(parsed)) return []
    return parsed.filter(function(r) { return r && r.kind === "unifying" })
  } catch (e) {
    return []
  }
}

function kindLabel(kind) {
  if (!kind || kind === "unknown") return "Device"
  return kind.charAt(0).toUpperCase() + kind.slice(1)
}

// Nerd Font (Material Design Icons) glyphs, keyed by the receiver helper's
// device kind strings.
var KIND_ICONS = {
  keyboard: "󰌌", // md-keyboard
  numpad: "󰌌",
  mouse: "󰍽",    // md-mouse
  trackball: "󰍽",
  touchpad: "󰍽",
  presenter: "󰑔", // md-remote
  remote: "󰑔",
  tablet: "󰓶",    // md-tablet
  gamepad: "󰊖",   // md-gamepad
  joystick: "󰊖"
}

function kindIcon(kind) {
  return KIND_ICONS[kind] || "󰾰" // md-devices fallback
}

// Nerd Font (Material Design Icons) battery glyphs, one per 10% step, so the
// icon shown roughly matches the number next to it.
var BATTERY_ICONS = {
  100: "󰁹",
  90: "󰂂",
  80: "󰂁",
  70: "󰂀",
  60: "󰁿",
  50: "󰁾",
  40: "󰁽",
  30: "󰁼",
  20: "󰁻",
  10: "󰁺",
  0: "󰂎"
}

// Same battery glyphs, but each with a bolt through it — used whenever a
// numeric level is charging, so the icon reflects both the level and the
// fact that it's going up rather than down.
var BATTERY_CHARGING_ICONS = {
  100: "󰂅",
  90: "󰂋",
  80: "󰂊",
  70: "󰢞",
  60: "󰂉",
  50: "󰢝",
  40: "󰂈",
  30: "󰂇",
  20: "󰂆",
  10: "󰢜"
}

// md-battery_charging — the plain "battery with a bolt" glyph, used when a
// device reports it's charging but has no numeric level (nothing to pick a
// stepped icon from — see deviceStatusLabel) or its level rounds to 0%,
// which has no dedicated charging-step glyph.
var BATTERY_CHARGING_ICON = "󰂄"

function batteryIcon(device) {
  if (typeof device.battery === "number") {
    var step = Math.max(0, Math.min(100, Math.round(device.battery / 10) * 10))
    if (device.batteryStatus === "recharging") return BATTERY_CHARGING_ICONS[step] || BATTERY_CHARGING_ICON
    return BATTERY_ICONS[step] || ""
  }
  if (device.batteryStatus === "recharging") return BATTERY_CHARGING_ICON
  if (device.batteryStatus === "full") return BATTERY_ICONS[100]
  return ""
}

var BATTERY_STATUS_LABELS = {
  recharging: "Charging",
  full: "Full charge",
  discharging: "Discharging"
}

function deviceStatusLabel(device) {
  if (!device.online) return "Offline"
  if (typeof device.battery === "number") return device.battery + "%"
  // Some legacy HID++1.0 devices (e.g. a K800 actively charging) report a
  // charging status with no numeric level at all — better to show that
  // than nothing, since "no percentage" here doesn't mean "no info".
  if (device.batteryStatus && BATTERY_STATUS_LABELS[device.batteryStatus]) {
    return BATTERY_STATUS_LABELS[device.batteryStatus]
  }
  return ""
}

// A receiver that hasn't finished fetching a device's name over RF yet can
// answer with a not-ready placeholder instead — the helper already retries
// that on its end, but this is a last-resort backstop so raw control-byte
// garbage never has a chance to render even for a single frame.
function looksLikeName(name) {
  if (!name) return false
  for (var i = 0; i < name.length; i++) {
    var code = name.charCodeAt(i)
    if (code < 32 || code === 127) return false
  }
  return true
}

function deviceName(device) {
  if (looksLikeName(device.name)) return device.name
  return kindLabel(device.kind)
}

// True when the receiver-level error is specifically a hidraw permission
// failure (missing/stale udev rule) — the one case the panel's "Fix
// permissions" button can actually do something about.
function isPermissionError(error) {
  return typeof error === "string" && error.indexOf("Permission denied") !== -1
}

// Bit 0 of the Bolt discovery "authentication" byte is what the device
// itself reports it wants: a typed passkey (bit set) or a click-sequence
// passkey (bit clear) — this is the device's own stated capability, not
// something inferred from its reported kind. Matches Solaar's
// `authentication & 0x01` check (lib/solaar/ui/pair_window.py).
function boltUsesTypedPasskey(authentication) {
  return !!(authentication & 1)
}

// For a click-confirmed device (no keys to type on — almost always a
// mouse), the passkey is entered as a Left/Right button-click sequence:
// the passkey number in 10-bit binary, most-significant bit first, each
// bit "1" a right click and "0" a left click — then both buttons together
// to confirm, the click equivalent of pressing Enter after typing. Matches
// Solaar's `f"{int(passkey):010b}"` conversion.
function boltClickSequence(passkey) {
  var n = parseInt(passkey, 10)
  if (isNaN(n)) return []
  var bits = Math.max(0, n).toString(2)
  while (bits.length < 10) bits = "0" + bits
  var clicks = []
  for (var i = 0; i < bits.length; i++) clicks.push(bits[i] === "1" ? "Right" : "Left")
  return clicks
}

if (typeof module !== "undefined") {
  module.exports = {
    parseReceivers: parseReceivers,
    kindLabel: kindLabel,
    kindIcon: kindIcon,
    batteryIcon: batteryIcon,
    deviceStatusLabel: deviceStatusLabel,
    deviceName: deviceName,
    isPermissionError: isPermissionError,
    boltUsesTypedPasskey: boltUsesTypedPasskey,
    boltClickSequence: boltClickSequence
  }
}
