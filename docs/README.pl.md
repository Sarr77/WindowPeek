# WindowPeek

Znajdź okno i od razu do niego przejdź.

WindowPeek zbiera otwarte okna na jednej liście dostępnej z paska Omarchy.
Możesz szukać na wszystkich workspace’ach i monitorach, podejrzeć okno przed
przełączeniem albo przenieść je w inne miejsce. Już nigdy nie zgubisz zakładki
w grupach okien Hyprlanda.

[English](../README.md) · [Instrukcja (EN)](GUIDE.md) · [Historia zmian (EN)](../CHANGELOG.md)

![WindowPeek w stylu Wallpaper, z listą po najechaniu i podglądem Instagramu w Chromium](../preview.png)

## Instalacja

```sh
omarchy plugin add https://github.com/Sarr77/WindowPeek --enable
```

Wtyczka pojawi się po lewej stronie paska. Możesz ją przenieść w edytorze paska Omarchy.
**Super + Alt + P** otwiera ją na aktywnym monitorze. Skrót włącza się automatycznie,
jeśli ta kombinacja nie jest już zajęta. Jeśli jest, wybierz inną w **Ustawienia →
Sterowanie → Skróty klawiatury i myszy**.

Wymagane jest Omarchy Quattro z paskiem Quickshell oraz API okien Hyprlanda w Lua.
Testowano na Omarchy 4.0.4, Hyprlandzie 0.56.2, Quickshell 0.3.1 i Qt 6.11.2.
Instalacja i automatyczne aktualizacje używają Pythona 3 i Gita, dostępnych w Omarchy.
Pierwsza kontrola kontrastu tapety używa ImageMagick, również dostępnego w Omarchy.
Instalację lokalną opisuje [dokumentacja deweloperska (EN)](DEVELOPMENT.md).

## Obsługa

Akcje klawiatury i modyfikatory myszy można zmieniać w **Ustawienia → Sterowanie →
Skróty klawiatury i myszy**. Edytor sprawdza konflikty, pozwala resetować pojedyncze
skróty i zapisuje zmiany dopiero po Zastosuj. Poniżej opisane są skróty domyślne.

Najedź na **WindowPeek**, żeby zobaczyć listę okien. Kliknij jego nazwę, żeby
rozwinąć ten sam panel i szukać po nazwie aplikacji lub tytule okna. Listę możesz
przewijać. Kolejne kliknięcie nazwy na pasku zamyka panel.

| W obu widokach listy | Działanie |
| --- | --- |
| Kliknięcie okna lub jego podglądu | Przejdź do okna lub zakładki na dotychczasowym monitorze |
| **Ctrl + klik** | Otwórz małe menu wyboru workspace’u |
| **Ctrl + Shift + klik** | Przenieś okno na bieżący workspace tego monitora i aktywuj je |
| Przytrzymanie **Shift** | Ukryj podglądy zawartości podczas przeglądania listy |
| Przytrzymanie **Ctrl** | Pokaż cyfry skrótów przy widocznych oknach i tabach |
| **Ctrl + 1–9 / 0** | Przejdź do okna lub tabu z tą cyfrą; 0 wybiera dziesiąty element |
| **Super + Alt + P**, potem **1–9 / 0** | Otwórz WindowPeek i przez pięć sekund wybierz widoczne okno bez Ctrl; działa też numpad |
| **Page Up / Page Down** | Przewiń listę o stronę |
| **Home / End** | Przejdź do pierwszego lub ostatniego okna; przy wpisanym zapytaniu przesuń kursor tekstowy |
| Prawy klik w głównym panelu | Zamknij WindowPeek wraz z podglądem |

Przytrzymaj **Shift**, żeby przeglądać listę bez pokazywania podglądów zawartości —
przydatne podczas streamowania lub udostępniania ekranu. Tytuły okien nadal są
widoczne.

Rozwinięty panel ma też przyciski **Przenieś** i obsługę klawiatury. Strzałki ↑ / ↓
wybierają okno, ← / → przechodzą między oknem a przyciskiem Przenieś, a Enter
wykonuje wybraną akcję. Przytrzymaj **Ctrl**, żeby zobaczyć cyfry przy widocznych
oknach i tabach, i naciśnij **1–9 / 0**, żeby przejść do wybranego elementu.
Działa to również w hoverze i z Ctrl trzymanym przed otwarciem, także na klawiaturze
numerycznej z włączonym lub wyłączonym Num Lock. Numeracja zmienia
się przy przewijaniu. W **Ustawienia → Lista okien** można wyrównać cyfry do prawej;
wtedy oznaczenie aktywnego okna przesuwa się obok nich. **Sterowanie** w ustawieniach opisuje
wszystkie gesty i skróty.

WindowPeek można obsługiwać w pełni z klawiatury: **Super + Alt + P** otwiera listę
na aktywnym monitorze i pokazuje numerki przez pięć sekund. W tym czasie wystarczy
sama cyfra z górnego rzędu lub numpada. Pisanie od razu rozpoczyna wyszukiwanie
i kończy ten tryb; po pięciu sekundach nadal działa **Ctrl + 1–9 / 0**.
Skrót otwierania jest dostępny automatycznie po włączeniu wtyczki, jeśli nie jest
już zajęty. Wtyczka zachowuje istniejące przypisania i nie edytuje konfiguracji
Hyprlanda. Więcej w [instrukcji klawiatury (EN)](GUIDE.md#keyboard-controls).

Scratchpad i inne specjalne workspace’y są domyślnie uwzględnione. Karty
przeglądarki i dokumenty wewnątrz aplikacji nie są osobnymi pozycjami na liście.
Ukryta aplikacja, która przestała odświeżać obraz, może pokazywać ostatnią dostępną klatkę.

## Ustawienia

Do wyboru jest 30 języków, kolory, rozmiar panelu i tekstu na pasku oraz własne
napisy. Zmiany kolorów, rozmiaru i tekstów widać podczas edycji. **Zastosuj** je
zapisuje, a **Anuluj** przywraca poprzednie ustawienia. Ikona **↺** przywraca wartość domyślną.

**Personalizacja** oferuje tło jednolite, tapetę i przezroczystość. Domyślny jest
tryb tapety z włączonym delikatnym ziarnem i wyłączonym rozmyciem. Pokazuje obraz
pulpitu. Przezroczystość zapisuje
osobno dla każdego motywu: zwykle zaczyna od 70%, obniżając tę wartość tylko przy
bardzo słabym kontraście. Reset przywraca początkowy poziom danego motywu.
Tryb przezroczystości pokazuje rzeczywiste okna pod panelem i zaczyna od 8%.

Kolory, jasność i przezroczystość pól można zapisywać w presetach dla jednego lub
wszystkich motywów. Panel, wiersze okien, sekcje menu i ziarno mają osobne
ustawienia. Więcej w [opisie wyglądu (EN)](GUIDE.md#panel-background).

W edytorze kolorów możesz kliknąć tło panelu, wiersz okna, akcent lub sekcję menu
w podglądzie, aby wybrać ten element do edycji. Podgląd jest na górze,
przed kontrolkami; kliknięcie nie przewija widoku. Dotychczasowe zmiany pozostają
w wersji roboczej do użycia **Zastosuj**.

**Przywróć domyślne kolory** resetuje kolory, jasność i przezroczystość pól
w wybranym zakresie motywów. Zachowuje zapisane presety; nie wczytuje żadnego z nich.

Możesz wyłączyć otwieranie panelu po najechaniu, podglądy okien lub sprężystość
przewijania, a także wybrać zwartą listę. Pasek i podglądy okien mają osobne
opóźnienia. Ustaw oba na **0** i wyłącz **Animacje okienek**, żeby otwierały się od razu.
Ramka podglądu może dopasować się do proporcji okna, a ciemne wypełnienie pod
obrazem można wyłączyć. Środkowy klik w wolnym miejscu panelu przełącza między
listą po najechaniu a widokiem rozwiniętym.

Przycisk **?** steruje podpowiedziami po najechaniu kursorem. Początkowo są
włączone i wyłączają się po 200 wyświetleniach łącznie na wszystkich monitorach.
Po ręcznym włączeniu działają do ręcznego wyłączenia. Ustawienia pozostają
zapisane po restarcie, aktualizacji i ponownej instalacji.

## Aktualizacje

Automatyczne aktualizacje są domyślnie włączone. Pierwsza kontrola następuje około
minuty po uruchomieniu, jeśli danego dnia jeszcze jej nie było, a kolejne co
6 godzin działania. Restarty zachowują termin. WindowPeek instaluje wyłącznie niezmienne wydania GitHub, których
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
chcesz je również zresetować. Automatyczny skrót jest zwalniany po wyłączeniu
lub usunięciu wtyczki. Jeśli dodałeś własny skrót, usuń też jego wpis.

## Dane i uprawnienia

WindowPeek odczytuje lokalny stan okien i monitorów, motyw oraz ikony aplikacji.
Używa `hyprctl` do przełączania i przenoszenia okien. Podglądy pozostają w pamięci
i są zwalniane po zamknięciu. Tytuły okien i podglądy nie są zapisywane na dysku.
Wtyczka udostępnia Super + Alt + P, jeśli skrót jest wolny. Zachowuje istniejące
przypisania i nie edytuje plików konfiguracji Hyprlanda.

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
