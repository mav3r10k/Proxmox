## Proxmox Härtung
Nach der Installation sollte der Proxmox Server wie alle anderen Systeme gehärtet werden. Dazu zählen die Abschottung via Firewallskript, sichere Verschlüsselung des HTTPS-Verkehrs, aber auch Kernelparameter und eine maximale Anzahl Anmeldeversuche bevor man eine voreingestellte Zeit gebannt wird.

 

## Fail2Ban für das WebUI

Das WebUI verfügt von Haus aus über keinen Mechanismus, der nur eine bestimmte Anzahl Anmeldeversuche zulässt und bei Überschreitung die Quell-IP sperrt. Dies lässt sich jedoch mit Fail2Ban problemlos regeln. Von Haus aus ist SSH bereits überwacht. Müssen wir Fail2Ban nur noch beibringen, dass es die Logs des WebUI überwachen soll.

Dazu an die /etc/fail2ban/jail.conf folgendes unten anhängen:

[proxmox2]
enabled = true
port    = https,http,8006
filter  = proxmox2
logpath  = /var/log/daemon.log
maxretry = 7
bantime  = 43200
Nun /etc/fail2ban/filter.d/proxmox2.conf anlegen und füllen:

[Definition]
# Option:  failregex
# Notes.:  regex to match the password failure messages in the logfile. The
#          host must be matched by a group named "host". The tag "<HOST>" can
#          be used for standard IP/hostname matching and is only an alias for
#          (?:::f{4,6}:)?(?P<host>\S+)
# Values:  TEXT
#
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.*msg=.*
# Option:  ignoreregex
# Notes.:  regex to ignore. If this regex matches, the line is ignored.
# Values:  TEXT
#
ignoreregex =
 

## Sichere Cipher für das WebUI

Wir setzen nicht nur sichere Cipher ein, sondern sorgen dafür, dass das WebUI nur von einem Rechner (Jumphost) aus erreichbar ist. Es lassen sich auch ganze Subnetze verwenden oder mehrere IPs. Einfach per Leerschritt getrennt alles aufzählen.

### Sichere Cipher verwenden
CIPHERS='ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:!aNULL:!MD5:!DSS'

COMPRESSION="0"
HONOR_CIPHER_ORDER="1"

### WebUI nur von einem bestimmten Client erlauben.
DENY_FROM="all"
ALLOW_FROM="192.168.2.10"
POLICY="allow"

 

## NFS deaktivieren

Sofern kein NFS benötigt wird, kann es auch deaktiviert werden. Dazu einfach in der Datei /etc/default/nfs-common den Wert NEED_STATD=no setzen.

 

## RPC deaktivieren

systemctl disable --now rpcbind.service rpcbind.socket
Danach den Server neu starten.

 

## IPv6 abschalten

Sofern kein IPv6 gebraucht wird bzw. man genau weiß was das bedeutet, sollte es abgeschaltet werden. Dazu in der /etc/sysctl.conf folgendes eintragen:

net.ipv6.conf.all.disable_ipv6 = 1

 

## Postfix auf IPv4 festlegen

Auch hier gilt: Was nicht gebraucht wird, kann abgeschaltet werden. Dazu die Datei /etc/postfix/main.cf öffnen und folgendes eintragen:

inet_protocols = ipv4

Postfix mit systemctl restart postfix.service

 

## SSH absichern

Hier muss man sich im Klaren sein, dass die folgenden beiden Empfehlungen nur möglich sind, wenn der Proxmoxhost singulär betrieben wird. Sobald ein Teil eines Clusters werden soll, führt das zu Ärger.

Die Anzahl der Login-Versuche, die bei Falscheingabe zum Aussperren über einen bestimmten Zeitrum führt, ist bereits mit Fail2Ban geschehen. Durch die Installation ist automatisch SSH gesichert. Vielleicht hier noch in der Konfiguration das Zeitfenster festlegen in der die Sperrung greifen soll.

Für die Anmeldung mittels Zertifikat wird in der sshd_config die Direktive "PubkeyAuthentication yes" gesetzt. Zeitgleich deaktiviert man den Passwortlogin mit "PasswordAuthentication no". So ist ein Zugriff mittels Passwort nicht mehr möglich

Den SSH Port verlegt man oberhalb 50000, der noch frei ist. Das wird ebenfalls in der sshd_config erledigt.

Direkter Root-Login sollte untersagt sein. Dafür wird in der sshd_config die Direktive "PermitRootLogin no" verwendet.

Weitere Anregungen zur Absicherung von SSH findet sich hier.

 

## Gültige Zertifikate einsetzen

Speziell dann, wenn der Server in einem unsicheren Netzwerk betrieben wird, sollte unbedingt eine nachvollziehbare Zertifikatkette vorhanden sein, um "Man in the middle"-Attacken vorzubeugen. Entweder man betreibt eine eigene PKI oder man kauft sich Zertifikate von namhaften Ausstellern wie bspw. der Bundesdruckerei.

 

## Kernelparameter setzen

In der Datei /etc/sysctl.conf lassen sich die Kernelparameter einstellen. Nach einer Empfehlung des BSI und CIS wären die folgenden ein Muss:

### Forwarding deaktivieren
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

### Packet Redirect deaktivieren
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

### Routed Packets nicht akzeptieren
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

### ICMP Redirects nicht akzeptieren
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

### Secure ICMP Redirects nicht akzeptieren
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

### Suspicious packets müssen geloggt werden
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

### Broadcast ICMP Requests müssen ignoriert werden
net.ipv4.icmp_echo_ignore_broadcasts = 1

### bogus ICMP responses müssen ignoriert werden
net.ipv4.icmp_ignore_bogus_error_responses = 1

### Reverse Path Filtering aktivieren
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

### TCP SYN Cookies müssen aktivieren werden
net.ipv4.tcp_syncookies = 1

### IPv6 router advertisements deaktivieren
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0

 

## Proxmox 2FA einsetzen

Es sollte, je nach Standort und Gefährdung eine 2FA implementiert werden.

 

## Trennung WebUI und VMs

Die meisten Server haben mindestens zwei Netzwerk-Schnittstellen. Es ist eine gute Idee das WebUI alleine über eine Schnittstelle (vmbr0) und die VMs auf der anderen Schnittstelle (vmbr1) zu betreiben. Sinnvollerweise ist vmbr0 separat und besser sogar nur im Manage-Netzwerk.

 

## Proxmox Firewall einsetzen

Proxmox bietet eine Firewall, die sehr bequem über das WebUI verwaltet werden kann. Dabei muss man allerdings verstehen wie sich das gedacht wurde, wie es funktionieren soll, was ich kurz erklären will:

Wenn man das WebUI von Proxmox öffnet, dann wird sicherlich schon aufgefallen sein, dass dem Host (pve) das "Datacenter" übergeordnet ist. Das liegt schlicht daran, weil Proxmox für den Clusterbetrieb konzipiert ist und sich alle Knoten (PVEs) unterhalb versammeln. Einige Einstellungen, wie bspw. die Firewall, können "clusterweit"  eingestellt werden, um nicht die selbe Einstellung an jedem Knoten einzeln durchführen zu müssen. So auch die Firewall.

Wir beginnen mit der Aktivierung der Firewall auf Datacenter-Ebene:

Klick auf Datacenter
Klick auf Firewall
Klick auf Options
Auf der rechten Seite: Doppel-Click auf Firewall und dort die Checkbox aktivieren
Die Firewall ist nun aktiviert. Es dauert einen kurzen  Moment. Ein Ping auf die IP des PVE zeigt, dass ICMP-Echo nicht mehr geht. Ein iptables -nvL zeigt die nun greifenden Iptables-Regeln. Es fällt auf, dass nicht nur Port 8006 und 22 offen sind, sondern auch 3128. Dieser ist ein Squid Proxy für den VNC. Wer das nicht benötigt, der sollte eine neue Regel auf Datacenter-Ebene erstellen, die 3128 blockt.

 

Klick auf Datacenter
Klick auf Firewall
Oben auf Add klicken und es öffnet sich ein neues Fenster.
In dem Fenster wie folgt ausfüllen:
Direction: in
Action: DROP
Enable: (Haken setzen)
Protocol: tcp
Dest-Port: 3128
Dann auf das blaue "Add" klicken und die neue Regel ist kurz drauf aktiv.
Möchte man auf einzelnen Knoten die Firewall regeln, so klickt man entsprechend auf den den Knoten der gemeint ist, dann auf Firewall usw... Das Gleiche lässt sich dann auch mit den einzelnen VMs erledigen.
