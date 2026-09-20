# WindowPeek

Znajdź okno i od razu do niego przejdź.

WindowPeek zbiera otwarte okna na jednej liście dostępnej z paska Omarchy.
Możesz szukać na wszystkich workspace’ach i monitorach, podejrzeć okno przed
przełączeniem albo przenieść je w inne miejsce. Zakładki w grupach okien
Hyprlanda są widoczne osobno.

[English](../README.md) · [Instrukcja (EN)](GUIDE.md) · [Historia zmian (EN)](../CHANGELOG.md)

![Lista okien, wyszukiwanie i przenoszenie w WindowPeek](../preview.png)

## Instalacja

```sh
omarchy plugin add https://github.com/Sarr77/WindowPeek --enable
```

Wtyczka pojawi się po lewej stronie paska. Możesz ją przenieść w edytorze paska Omarchy.

Wymagane jest Omarchy Quattro z paskiem Quickshell oraz API okien Hyprlanda w Lua.
Testowano na Omarchy 4.0.4, Hyprlandzie 0.56.2, Quickshell 0.3.1 i Qt 6.11.2.
Instalacja i automatyczne aktualizacje używają Pythona 3 i Gita, dostępnych w Omarchy.
Instalację lokalną opisuje [dokumentacja deweloperska (EN)](DEVELOPMENT.md).

## Obsługa

Najedź na **WindowPeek**, żeby zobaczyć listę okien. Kliknij jego nazwę, żeby
rozwinąć ten sam panel i szukać po nazwie aplikacji lub tytule okna. Listę możesz
przewijać. Kolejne kliknięcie nazwy na pasku zamyka panel.

| W obu widokach listy | Działanie |
| --- | --- |
| Kliknięcie okna lub jego podglądu | Przejdź do okna lub zakładki na dotychczasowym monitorze |
| **Ctrl + klik** | Otwórz małe menu wyboru workspace’u |
| **Ctrl + Shift + klik** | Przenieś okno na bieżący workspace tego monitora i aktywuj je |
| Przytrzymanie **Ctrl** | Ukryj podglądy zawartości podczas przeglądania listy |
| Prawy klik w głównym panelu | Zamknij WindowPeek wraz z podglądem |

Przytrzymaj **Ctrl**, żeby przeglądać listę bez pokazywania podglądów zawartości —
przydatne podczas streamowania lub udostępniania ekranu. Tytuły okien nadal są
widoczne.

Rozwinięty panel ma też przyciski **Przenieś** i obsługę klawiatury. Strzałki ↑ / ↓
wybierają okno, ← / → przechodzą między oknem a przyciskiem Przenieś, a Enter
wykonuje wybraną akcję. **Sterowanie** w ustawieniach opisuje wszystkie gesty i skróty.
Opcjonalny skrót **Super + Alt + P** możesz dodać według
[instrukcji konfiguracji (EN)](GUIDE.md#keyboard-controls).

Scratchpad i inne specjalne workspace’y są domyślnie uwzględnione. Karty
przeglądarki i dokumenty wewnątrz aplikacji nie są osobnymi pozycjami na liście.
Ukryta aplikacja, która przestała odświeżać obraz, może pokazywać ostatnią dostępną klatkę.

## Ustawienia

Do wyboru jest 30 języków, kolory, rozmiar panelu i tekstu na pasku oraz własne
napisy. Zmiany kolorów, rozmiaru i tekstów widać podczas edycji. **Zastosuj** je
zapisuje, a **Anuluj** przywraca poprzednie ustawienia. Ikona **↺** przywraca wartość domyślną.

Możesz wyłączyć otwieranie panelu po najechaniu, podglądy okien lub sprężystość
przewijania, a także wybrać zwartą listę. Pasek i podglądy okien mają osobne
opóźnienia. Ustaw oba na **0** i wyłącz **Animacje okienek**, żeby otwierały się od razu.

Przycisk **?** steruje podpowiedziami po najechaniu kursorem. Początkowo są
włączone i wyłączają się po 200 wyświetleniach łącznie na wszystkich monitorach.
Po ręcznym włączeniu działają do ręcznego wyłączenia. Ustawienia pozostają
zapisane po restarcie, aktualizacji i ponownej instalacji.

## Aktualizacje

Automatyczne aktualizacje są domyślnie włączone. WindowPeek sprawdza je raz
dziennie, gdy działa. Instaluje wyłącznie niezmienne wydania GitHub, których
dokładny commit został zweryfikowany w katalogu Omarchy. Błąd pobierania lub
weryfikacji pozostawia dotychczasową instalację bez zmian.

Mały przełącznik obok **?** pozwala je wyłączyć po potwierdzeniu. Kopie robocze
podłączone linkiem, forki, instalacje bez Gita i lokalnie zmieniony kod nie są
aktualizowane automatycznie. Więcej w [opisie aktualizacji (EN)](UPDATES.md).

## Usunięcie

```sh
omarchy plugin remove sarr.windowpeek
```

Okna pozostają na swoich miejscach. Preferencje zostają w
`~/.local/state/windowpeek/preferences.json` lub pod `$XDG_STATE_HOME/windowpeek`,
jeśli ta zmienna jest ustawiona. Usuń plik preferencji po odinstalowaniu, jeśli
chcesz je również zresetować. Jeśli dodałeś skrót klawiszowy, usuń też jego wpis.

## Dane i uprawnienia

WindowPeek odczytuje lokalny stan okien i monitorów, motyw oraz ikony aplikacji.
Używa `hyprctl` do przełączania i przenoszenia okien. Podglądy pozostają w pamięci
i są zwalniane po zamknięciu. Tytuły okien i podglądy nie są zapisywane na dysku.
Wtyczka nie zmienia skrótów klawiszowych.

Automatyczne aktualizacje łączą się z GitHubem i katalogiem Omarchy. Terminy i
wyniki sprawdzeń są zapisywane obok preferencji. Nie ma telemetrii. WindowPeek
działa wewnątrz powłoki Omarchy z uprawnieniami użytkownika, bez dostępu administratora.

## Pomoc i rozwój

[Zgłoś błąd](https://github.com/Sarr77/WindowPeek/issues) ·
[Praca nad kodem (EN)](DEVELOPMENT.md) · [Testy i ograniczenia (EN)](TESTING.md)

MIT · © 2026 [Sarr](https://github.com/Sarr77).
Wybrane komponenty pochodzą ze [ScratchPeek](https://github.com/Sarr77/ScratchPeek). Dostosowane kontrolki i logo Omarchy
zachowują [swoją licencję MIT](../vendor/omarchy/LICENSE).
[Informacje o pochodzeniu kodu (EN)](SCRATCHPEEK_REFERENCE.md).
