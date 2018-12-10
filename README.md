# spluix
Zabbix Agent - Splunk

# Dependencies
## Packages
* ksh
* jq
* curl

__**Debian/Ubuntu**__

```
#~ sudo apt install ksh jq curl
#~
```
__**Red Hat**__
```
#~ sudo yum install ksh jq curl
#~
```
# Deploy
Default variables:

NAME|VALUE
----|-----
SPLUNK_URL|http://localhost:8089
SPLUNK_USER|monitor
SPLUNK_PASS|xxxxxxx
CACHE_DIR|<empty>
CACHE_TTL|<empty>

*Note: this variables has to be saved in the config file (spluix.conf) in the same directory than the script.*

## Zabbix
Zabbix user has to have sudo privileges (you can limit the sudo access).

```
#~ cat /etc/sudoers.d/user_zabbix
# Allow the user zabbix to execute any command without password
zabbix	ALL=(ALL:ALL) NOPASSWD:ALL
```
Then you can run the deploy_zabbix script
```
#~ git clone https://github.com/sergiotocalini/spluix.git
#~ sudo ./spluix/deploy_zabbix.sh "<SPLUNK_URL>" "<SPLUNK_USER>" "<SPLUNK_PASS>" "<CACHE_DIR>" "<CACHE_TTL>"
#~ sudo systemctl restart zabbix-agent
``` 
*Note: the installation has to be executed on the zabbix agent host and you have to import the template on the zabbix web. The default installation directory is /etc/zabbix/scripts/agentd/spluix*
