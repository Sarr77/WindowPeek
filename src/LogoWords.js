// Effect names are shared with Omarchy's screensaver; controls use the UI locale.
var en = {
    randomGif:"Random GIF", randomHelp:"A different Omarchy GIF on each opening", nextGif:"Next GIF",
    openingEffect:"Opening effect", pixels:"Pixels", scatter:"Scatter", wipe:"Wipe", blinds:"Blinds", iris:"Iris", dissolve:"Fade in",
    openingHelp:"Plays once when shown · GIF playback continues",
    centerHorizontal:"Center horizontally", centerVertical:"Center vertically",
    widthHandle:"Double-click to center horizontally · drag to change width",
    heightHandle:"Double-click to center vertically · drag to change height",
    scaleHandle:"Drag to resize · keep current proportions",
    resetArtwork:"Restore default artwork, size, position, colors, effects and playback",
    adjust:"Hold Ctrl: drag to move · double-click to center · wheel to resize",
    saveFailed:"Could not save — try again", library:"Pictures & animations", search:"Search animations…", defaults:"Originals",
    animations:"Omarchy effects", files:"Your files", browse:"Choose a file…",
    recent:"Recent files", emptyFiles:"Choose an image or GIF — the original file stays unchanged",
    preview:"Preview", replay:"Replay", theme:"Use theme colors", motion:"Motion",
    none:"None", pulse:"Pulse", float:"Float", sway:"Sway", spin:"Spin", fade:"Breathe",
    restore:"Restore original", use:"Use this", selected:"Selected", remove:"Remove from recent",
    fit:"Images keep their proportions", paused:"Preview paused", missing:"This file is unavailable — choose it again",
    original:"Default", customize:"Choose picture or animation", saving:"Saving…"
};
var pl = {
    randomGif:"Losowy GIF", randomHelp:"Inny GIF Omarchy przy każdym otwarciu", nextGif:"Następny GIF",
    openingEffect:"Efekt pojawiania", pixels:"Piksele", scatter:"Rozsypane fragmenty", wipe:"Odsłanianie", blinds:"Poziome pasy", iris:"Kołowe odkrywanie", dissolve:"Łagodne pojawianie",
    openingHelp:"Odtwarza się przy otwarciu · GIF gra dalej",
    centerHorizontal:"Wyśrodkuj w poziomie", centerVertical:"Wyśrodkuj w pionie",
    widthHandle:"Kliknij dwukrotnie, by wyśrodkować w poziomie · przeciągnij, by zmienić szerokość",
    heightHandle:"Kliknij dwukrotnie, by wyśrodkować w pionie · przeciągnij, by zmienić wysokość",
    scaleHandle:"Przeciągnij, by zmienić rozmiar · zachowaj obecne proporcje",
    resetArtwork:"Przywróć domyślną grafikę, rozmiar, położenie, kolory, efekty i odtwarzanie",
    adjust:"Przytrzymaj Ctrl: przeciągnij, by przesunąć · dwuklik wyśrodkowuje · kółko zmienia rozmiar",
    saveFailed:"Nie udało się zapisać — spróbuj ponownie", library:"Obrazy i animacje", search:"Szukaj animacji…", defaults:"Oryginalne",
    animations:"Efekty Omarchy", files:"Własne pliki", browse:"Wybierz plik…",
    recent:"Ostatnie pliki", emptyFiles:"Wybierz obraz lub GIF — oryginalny plik pozostaje bez zmian",
    preview:"Podgląd", replay:"Odtwórz ponownie", theme:"Kolory motywu", motion:"Ruch",
    none:"Brak", pulse:"Pulsowanie", float:"Unoszenie", sway:"Kołysanie", spin:"Obrót", fade:"Oddychanie",
    restore:"Przywróć oryginalne", use:"Zastosuj", selected:"Wybrane", remove:"Usuń z ostatnich",
    fit:"Obrazy zachowują proporcje", paused:"Podgląd zatrzymany", missing:"Plik jest niedostępny — wybierz go ponownie",
    original:"Domyślne", customize:"Wybierz obraz lub animację", saving:"Zapisywanie…"
};
function words(locale) { return String(locale).split(/[-_]/)[0] === "pl" ? pl : en; }
