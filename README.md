# FHEM-Addonrepo
Einfacheres updaten von externen FHEM AddOns
Ich kopiere die einfach hierher und update die so ohne viel Rumgespiele.

Installation:
In der FHEM Kommandozeile ausführen (copy&paste + [Enter])

update add https://raw.githubusercontent.com/steigerbalett/FHEM-Addonrepo/master/controls_addonrepo.txt


Deinstallation (nicht mehr updaten)

update delete  https://raw.githubusercontent.com/steigerbalett/FHEM-Addonrepo/master/controls_addonrepo.txt

+++++++++++++++++++++++++++++++++++++++

Alternativ kann man auch die Dateien nur einmal zu FHEM hinzufügen ohne bei jedem Update die neuste Version zu laden. Dies muss dann immer manuell gemacht werden:

update all  https://raw.githubusercontent.com/steigerbalett/FHEM-Addonrepo/master/controls_addonrepo.txt

Manuelle überprüfung auf neue Versionen:

update check  https://raw.githubusercontent.com/steigerbalett/FHEM-Addonrepo/master/controls_addonrepo.txt
