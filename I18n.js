.import "translations/en.js" as En
.import "translations/pl.js" as Pl
.import "translations/de.js" as De
.import "translations/fr.js" as Fr
.import "translations/es.js" as Es
.import "translations/pt-BR.js" as PtBr
.import "translations/pt-PT.js" as PtPt
.import "translations/it.js" as It
.import "translations/nl.js" as Nl
.import "translations/sv.js" as Sv
.import "translations/da.js" as Da
.import "translations/nb.js" as Nb
.import "translations/fi.js" as Fi
.import "translations/cs.js" as Cs
.import "translations/sk.js" as Sk
.import "translations/uk.js" as Uk
.import "translations/ru.js" as Ru
.import "translations/tr.js" as Tr
.import "translations/ro.js" as Ro
.import "translations/hu.js" as Hu
.import "translations/el.js" as El
.import "translations/ar.js" as Ar
.import "translations/hi.js" as Hi
.import "translations/id.js" as Id
.import "translations/vi.js" as Vi
.import "translations/th.js" as Th
.import "translations/ja.js" as Ja
.import "translations/ko.js" as Ko
.import "translations/zh-CN.js" as ZhCn
.import "translations/zh-TW.js" as ZhTw

// UTF-8 source dictionaries. No runtime downloads or global Qt translator changes.
var languages = [
  { code: "en", name: "English" }, { code: "pl", name: "Polski" },
  { code: "de", name: "Deutsch" }, { code: "fr", name: "Français" },
  { code: "es", name: "Español" }, { code: "pt-BR", name: "Português (Brasil)" },
  { code: "pt-PT", name: "Português (Portugal)" }, { code: "it", name: "Italiano" },
  { code: "nl", name: "Nederlands" }, { code: "sv", name: "Svenska" },
  { code: "da", name: "Dansk" }, { code: "nb", name: "Norsk bokmål" },
  { code: "fi", name: "Suomi" }, { code: "cs", name: "Čeština" },
  { code: "sk", name: "Slovenčina" }, { code: "uk", name: "Українська" },
  { code: "ru", name: "Русский" }, { code: "tr", name: "Türkçe" },
  { code: "ro", name: "Română" }, { code: "hu", name: "Magyar" },
  { code: "el", name: "Ελληνικά" }, { code: "ar", name: "العربية", rtl: true },
  { code: "hi", name: "हिन्दी" }, { code: "id", name: "Bahasa Indonesia" },
  { code: "vi", name: "Tiếng Việt" }, { code: "th", name: "ไทย" },
  { code: "ja", name: "日本語" }, { code: "ko", name: "한국어" },
  { code: "zh-CN", name: "简体中文" }, { code: "zh-TW", name: "繁體中文" }
];

function matchLocale(locale) {
  var tag = String(locale || "").trim().replace(/\..*$/, "").replace(/@.*$/, "").replace(/_/g, "-").toLowerCase();
  if (!/^[a-z]{2,3}(?:-[a-z0-9]{2,8})*$/.test(tag)) return "";
  var parts = tag.split("-");
  var base = parts[0];
  if (base === "zh") {
    // An explicit script takes precedence over territory (e.g. zh-Hans-HK).
    if (parts.indexOf("hant") >= 0) return "zh-TW";
    if (parts.indexOf("hans") >= 0) return "zh-CN";
    return parts.some(function(p) { return p === "tw" || p === "hk" || p === "mo"; }) ? "zh-TW" : "zh-CN";
  }
  if (base === "pt") return parts.indexOf("br") >= 0 ? "pt-BR" : "pt-PT";
  if (base === "no") base = "nb";
  if (base === "in") base = "id";
  for (var i = 0; i < languages.length; i++) if (languages[i].code.toLowerCase() === base) return languages[i].code;
  return "";
}

function language(setting, preferred, fallbackLocale) {
  var explicit = setting && setting !== "auto" ? matchLocale(setting) : "";
  if (explicit) return explicit;
  var candidates = Array.isArray(preferred) ? preferred : String(preferred || "").split(":");
  for (var i = 0; i < candidates.length; i++) {
    // The POSIX locale explicitly requests the source language.
    if (/^(C|POSIX)([.@]|$)/i.test(candidates[i])) return "en";
    var matched = matchLocale(candidates[i]);
    if (matched) return matched;
  }
  return matchLocale(fallbackLocale) || "en";
}

function nativeName(code) {
  for (var i = 0; i < languages.length; i++) if (languages[i].code === code) return languages[i].name;
  return "English";
}

function isRtl(code) { return code === "ar"; }

function hintText(text) {
  return String(text || "").split("\n").map(function(line) {
    return line.replace(/[.。۔]+(\s*)$/, "$1");
  }).join("\n");
}

function format(template, values) {
  return String(template).replace(/\{([a-zA-Z]+)\}/g, function(token, key) {
    return values && Object.prototype.hasOwnProperty.call(values, key) ? String(values[key]) : token;
  });
}

function workspaceTitle(name, translated) {
  if (!name) return translated.unknownWorkspace;
  if (name === "special:scratchpad") return translated.scratchpad;
  if (name.indexOf("special:") === 0) return format(translated.specialWorkspaceLabel, {name: name.slice(8)});
  return format(translated.workspaceLabel, {name: name});
}

function words(code) {
  var translated = catalogs[code] || catalogs.en;
  var result = {};
  Object.keys(catalogs.en).forEach(function(key) { result[key] = translated[key] || catalogs.en[key]; });
  return result;
}

function options(code, detected) {
  var w = words(code);
  return [{ value: "auto", label: w.automatic + " · " + nativeName(detected), description: "auto" }].concat(
    languages.map(function(item) { return { value: item.code, label: item.name, description: item.code }; }));
}

var catalogs = {
  "en": En.words,
  "pl": Pl.words,
  "de": De.words,
  "fr": Fr.words,
  "es": Es.words,
  "pt-BR": PtBr.words,
  "pt-PT": PtPt.words,
  "it": It.words,
  "nl": Nl.words,
  "sv": Sv.words,
  "da": Da.words,
  "nb": Nb.words,
  "fi": Fi.words,
  "cs": Cs.words,
  "sk": Sk.words,
  "uk": Uk.words,
  "ru": Ru.words,
  "tr": Tr.words,
  "ro": Ro.words,
  "hu": Hu.words,
  "el": El.words,
  "ar": Ar.words,
  "hi": Hi.words,
  "id": Id.words,
  "vi": Vi.words,
  "th": Th.words,
  "ja": Ja.words,
  "ko": Ko.words,
  "zh-CN": ZhCn.words,
  "zh-TW": ZhTw.words
};
