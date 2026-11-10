// What a display name may not say. Names are compared after folding accents, look-alike digits and
// symbols, and repeated letters, so "F.u.u.c.k" and "fvck" are caught as well as "fuck".
//
// ANYWHERE words are long and unambiguous: they are refused inside any name. WHOLE words are short
// or have innocent neighbours ("puta" sits inside "reputation", "rapist" inside "therapist", "zorra"
// squeezes to the name Zora), so they are refused only as a whole word of the name, or as the whole
// name. Common nicknames that look like slurs elsewhere (Spanish "Kike", for Enrique) are left out.

const ANYWHERE = [
  // English
  "nigger", "nigga", "faggot", "retard", "tranny", "spastic", "wetback", "beaner",
  "motherfucker", "fucker", "fucking", "cocksucker", "whore", "hitler",
  "pedophile", "paedophile", "pedofilo", "pederast",
  // Spanish
  "maricon", "subnormal", "gilipollas", "hijodeputa", "follador",
  "cabron", "putero", "mamada", "chupapollas", "sudaca", "moromierda",
];

const WHOLE = [
  // English
  "fuck", "fck", "shit", "ass", "arse", "asshole", "bitch", "dick", "cock", "pussy", "slut", "fag",
  "rape", "rapist", "porn", "sex", "penis", "vagina", "anal", "cum", "tits", "boobs", "wank", "twat", "prick",
  "cunt", "nazi", "chink",
  // Spanish
  "puta", "puto", "joder", "mierda", "coño", "cono", "culo", "pene", "verga", "pija", "chocho",
  "follar", "marica", "mongolo", "idiota", "imbecil", "putas", "putos", "perra", "polla", "zorra", "hdp",
];

const LOOKALIKE = { "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "8": "b", "@": "a", "$": "s", "!": "i", "|": "i", "v": "u" };

// Lower case, accents folded, digits and symbols read as the letters they imitate.
export function fold(text) {
  let out = "";
  for (const ch of text.normalize("NFKD").replace(/\p{M}+/gu, "").toLowerCase()) {
    out += LOOKALIKE[ch] ?? ch;
  }
  return out;
}

// Letters only, with runs of the same letter squeezed to one: "fuuuck" and "fuck" become "fuck".
function squeeze(text) {
  return text.replace(/[^\p{L}]+/gu, "").replace(/(\p{L})\1+/gu, "$1");
}

const ANYWHERE_SQUEEZED = ANYWHERE.map((w) => squeeze(fold(w)));
const WHOLE_SQUEEZED = new Set(WHOLE.map((w) => squeeze(fold(w))));
// The shortest spelling of each word, so a squeezed match is never shorter than the real word.
const WHOLE_LENGTH = new Map();
for (const w of WHOLE) {
  const key = squeeze(fold(w));
  WHOLE_LENGTH.set(key, Math.min(WHOLE_LENGTH.get(key) ?? Infinity, [...fold(w)].length));
}

// True when a name should be refused. `name` is already cleaned (cleanName).
export function blockedName(name) {
  const folded = fold(name);
  const all = squeeze(folded);
  if (ANYWHERE_SQUEEZED.some((w) => all.includes(w))) return true;
  const letters = folded.replace(/[^\p{L}]+/gu, "");
  for (const word of [letters, ...folded.split(/[\s_.'-]+/u)]) {
    const plain = word.replace(/[^\p{L}]+/gu, "");
    // Squeezed, but never shorter than the word it matches: "asss" is refused, the Spanish "As" is not.
    if (plain && WHOLE_SQUEEZED.has(squeeze(plain)) && WHOLE_LENGTH.get(squeeze(plain)) <= plain.length) return true;
  }
  return false;
}
