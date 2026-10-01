# WindowPeek

**Znajdź każde okno w kilka sekund.**

Hyprland świetnie organizuje okna. Problem zaczyna się wtedy, gdy praca rozkłada się na kilka workspace'ów, monitorów, zgrupowane taby i scratchpad. WindowPeek zbiera to wszystko w jednym miejscu i pozwala od razu przejść tam, gdzie chcesz.

Najedź na WindowPeek na barze Omarchy, aby przeglądać okna. Naciśnij **Super + Alt + P** i zacznij pisać, aby wyszukiwać. Podejrzyj okno przed przełączeniem albo przenieś je na inny workspace, monitor lub do scratchpada, bez zastanawiania się, gdzie właściwie się znajduje.

Dock, launcher, menu Start, Launchpad i Mission Control próbują rozwiązywać podobny problem, narzucając systemowe przyzwyczajenia. WindowPeek czyni odpowiedź Omarchy prostą: **znajdź okno, które już otworzyłeś - momentalnie.**

[Omarchy Plugins](https://plugins.omarchy.org/plugin.html?id=sarr.windowpeek) · [Instrukcja](https://github.com/Sarr77/WindowPeek/blob/main/docs/GUIDE.md) · [Ustawienia](https://github.com/Sarr77/WindowPeek/blob/main/docs/SETTINGS.md) · [Changelog](https://github.com/Sarr77/WindowPeek/blob/main/CHANGELOG.md)

![WindowPeek](https://raw.githubusercontent.com/Sarr77/WindowPeek/main/preview.png)

## Instalacja

```sh
omarchy plugin add https://github.com/Sarr77/WindowPeek --enable
```

WindowPeek pojawi się na barze Omarchy. Najedź na nazwę, aby przeglądać okna, albo naciśnij **Super + Alt + P**, aby pozostać przy klawiaturze czy filtrować tekstowo.

## Już je otworzyłeś. Nie szukaj drugi raz

Jeśli masz otwartych tylko kilka okien, natywna nawigacja Hyprlanda jest wystarczająca. WindowPeek zaczyna być przydatny, gdy pulpit staje się przestrzenią roboczą: przeglądarki, terminale, edytory, agenci, pliki i multimedia rozłożone na wielu workspace'ach i monitorach.

Z WindowPeek możesz:

- **Najechać i przeglądać** otwarte okna bezpośrednio z bara.
- **Szukać po tytule lub aplikacji**, zamiast pamiętać, gdzie znajduje się okno.
- **Podejrzeć okno przed przełączeniem**, również na innym workspace.
- **Przejść bezpośrednio** do okna lub taba w grupie Hyprlanda.
- **Przenosić okna** między workspace'ami, monitorami i scratchpadem.
- **Zostać przy klawiaturze** dzięki konfigurowalnym skrótom i numerowanemu wyborowi.
- **Natychmiast ukryć podglądy** klawiszem Shift podczas prezentacji lub udostępniania ekranu.
- **Zachować wygląd Omarchy** - WindowPeek automatycznie dopasowuje się do motywu, a jeśli chcesz, możesz zmienić praktycznie wszystko.

## Skróty klawiszowe

| Skrót | Działanie |
|----|----|
| **Super + Alt + P** | Otwórz WindowPeek |
| Pisanie | Wyszukuj okna |
| **Tab / Shift + Tab** | Przechodź między kontrolkami; lista okien jest jednym z kroków |
| **↑ / ↓** | Wybierz okno |
| **← / →**, potem **Enter** | Wybierz okno albo akcję Przenieś |
| **Shift + Enter** | Otwórz Przenieś dla wybranego okna |
| **Ctrl + 1–9 / 0** | Przejdź do ponumerowanego okna lub taba grupy |
| **Page Up / Page Down** | Przewiń o stronę |
| **Esc** | Wróć lub zamknij |

Po otwarciu przez **Super + Alt + P** klawisze numeryczne działają przez pięć sekund także bez Ctrl. **0** wybiera dziesiąte okno.

Skróty zmienisz w **Ustawienia → Sterowanie → Skróty klawiatury i myszy**.

[Pełna lista sterowania](https://github.com/Sarr77/WindowPeek/blob/main/docs/GUIDE.md#keyboard-controls)

## W stylu Omarchy

WindowPeek automatycznie dopasowuje się do aktualnego motywu Omarchy. Jeśli niczego nie zmienisz, będzie pasować do większości motywów. Możesz też zmienić tryb tła, przezroczystość, kolory, skalę, obszar listy, etykiety, animacje, podglądy, skróty i zachowania panelu.

Ustawienia obsługują **30 języków** i pokazują zmiany na żywo.

| Obszar | Możliwości |
|----|----|
| Panel | Tło z tapety, jednolite lub przezroczyste; opcjonalny blur i grain; dopasowanie do aktywnego stylu bara |
| Kolory | Kolory motywu Omarchy albo własna paleta z zapisywanymi presetami |
| Układ | Skala panelu i tekstu bara, przestronne lub kompaktowe wiersze, własne etykiety |
| Obrazy i animacje | Grafiki Omarchy, 37 wbudowanych efektów albo własne lokalne pliki z pozycjonowaniem i skalowaniem |
| Zachowanie | Czas podglądów, hover, przewijanie, skróty, podpowiedzi i akcje na oknach |

[Poznaj ustawienia](https://github.com/Sarr77/WindowPeek/blob/main/docs/SETTINGS.md) · [Ustawienia domyślne](https://github.com/Sarr77/WindowPeek/blob/main/docs/SETTINGS.md#defaults)

## Aktualizacje

Otwórz **Ustawienia → Sterowanie → Aktualizacje**, aby sprawdzić aktualizacje, zobaczyć zmiany i zainstalować je przez potwierdzenie w terminalu Omarchy.

Przełącznik **Automatyczne aktualizacje** w stopce włącza powiadomienia o nowych wersjach. Opcja **Zweryfikowane aktualizacje** może instalować w tle wydania zweryfikowane przez marketplace.

[Jak działają aktualizacje](https://github.com/Sarr77/WindowPeek/blob/main/docs/UPDATES.md)

## Prywatność

WindowPeek nie ma telemetrii.

Tytuły okien i podglądy nie są zapisywane na dysku. Sprawdzanie aktualizacji łączy się z GitHubem i katalogiem wtyczek Omarchy.

## Pomoc

Użyj ikony **?** dla kontekstowych podpowiedzi albo otwórz **Ustawienia → Sterowanie → Wskazówki i pomoc**.

[Zgłoś błąd lub pomysł](https://github.com/Sarr77/WindowPeek/issues) · [Rozwiązywanie problemów](https://github.com/Sarr77/WindowPeek/blob/main/docs/TROUBLESHOOTING.md) · [Znane problemy](https://github.com/Sarr77/WindowPeek/blob/main/docs/KNOWN_ISSUES.md)

## Usuwanie

```sh
omarchy plugin remove sarr.windowpeek
```

Zapisane ustawienia pozostają na miejscu i wrócą po ponownej instalacji.

## Development i podziękowania

[Wymagania i development](https://github.com/Sarr77/WindowPeek/blob/main/docs/DEVELOPMENT.md) · [Testy](https://github.com/Sarr77/WindowPeek/blob/main/docs/TESTING.md) · [Changelog](https://github.com/Sarr77/WindowPeek/blob/main/CHANGELOG.md)

MIT · © 2026 [Sarr](https://github.com/Sarr77)

Wybrane komponenty pochodzą ze [ScratchPeek](https://github.com/Sarr77/ScratchPeek); zaadaptowane kontrolki Omarchy oraz logo zachowują [swoją notę MIT](https://github.com/Sarr77/WindowPeek/blob/main/vendor/omarchy/LICENSE). Zobacz [pochodzenie kodu](https://github.com/Sarr77/WindowPeek/blob/main/docs/SCRATCHPEEK_REFERENCE.md).

[English](https://github.com/Sarr77/WindowPeek/blob/main/README.md) · Polski
