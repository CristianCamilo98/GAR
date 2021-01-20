#!/bin/bash

#Instalacion de Nagios Core

#Prerequisitos
sudo apt-get update
sudo apt-get install -y autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php7.0 libgd2-xpm-dev

#Descargamos el "Source"
cd /tmp
wget -O nagioscore.tar.gz https://github.com/NagiosEnterprises/nagioscore/archive/nagios-4.4.5.tar.gz
tar xzf nagioscore.tar.gz

#Compilamos
cd /tmp/nagioscore-nagios-4.4.5/
sudo ./configure --with-httpd-conf=/etc/apache2/sites-enabled
sudo make all

#Creamos Usuario y grupo
sudo make install-groups-users
sudo usermod -a -G nagios www-data

#Instalamos binarios
sudo make install

#Instalamos servicios y demonio
sudo make install-daemoninit

# Instalamos el modo comando
sudo make install-commandmode

#Instalamos los archivos de configuracion 
sudo make install-config

#Intalamos archivos de configuracion de apache
sudo make install-webconf
sudo a2enmod rewrite
sudo a2enmod cgi

#Configuramos Firewall
sudo ufw allow Apache
sudo ufw reload

#Reiniciamos apache2
sudo systemctl restart apache2.service

#Reiniciamos nagios
sudo systemctl start nagios.service


#Instalamos Nagios plugins
sudo apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
cd /tmp
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.2.1.tar.gz
tar zxf nagios-plugins.tar.gz
cd /tmp/nagios-plugins-release-2.2.1/
sudo ./tools/setup
sudo ./configure
sudo make
sudo make install


#Instalamos nagflux
sudo apt-get install -y golang golang-github-influxdb-usage-client-dev git 
echo "export GOPATH=$HOME/gorepo" >> ~/.bashrc
source ~/.bashrc
mkdir $GOPATH
go get -v -u github.com/griesbacher/nagflux
go build github.com/griesbacher/nagflux 
sudo mkdir -p /opt/nagflux
sudo cp $GOPATH/bin/nagflux /opt/nagflux/
sudo mkdir -p /usr/local/nagios/var/spool/nagfluxperfdata
sudo chown nagios:nagios /usr/local/nagios/var/spool/nagfluxperfdata 
sudo cp $GOPATH/src/github.com/griesbacher/nagflux/nagflux.service /lib/systemd/system/
sudo chmod +x /lib/systemd/system/nagflux.service
sudo systemctl daemon-reload
sudo systemctl enable nagflux.service

#Configuracion de Nagflux
cd /opt/nagflux
sudo sh -c "printf '[main]\n' > config.gcfg"
sudo sh -c "printf '\tNagiosSpoolfileFolder = \"/usr/local/nagios/var/spool/nagfluxperfdata\"\n' >> config.gcfg"
sudo sh -c "printf '\tNagiosSpoolfileWorker = 1\n' >> config.gcfg"
sudo sh -c "printf '\tInfluxWorker = 2\n' >> config.gcfg"
sudo sh -c "printf '\tMaxInfluxWorker = 5\n' >> config.gcfg"
sudo sh -c "printf '\tDumpFile = \"nagflux.dump\"\n' >> config.gcfg"
sudo sh -c "printf '\tNagfluxSpoolfileFolder = \"/usr/local/nagios/var/nagflux\"\n' >> config.gcfg"
sudo sh -c "printf '\tFieldSeparator = \"&\"\n' >> config.gcfg"
sudo sh -c "printf '\tBufferSize = 10000\n' >> config.gcfg"
sudo sh -c "printf '\tFileBufferSize = 65536\n' >> config.gcfg"
sudo sh -c "printf '\tDefaultTarget = \"all\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[Log]\n' >> config.gcfg"
sudo sh -c "printf '\tLogFile = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tMinSeverity = \"INFO\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDBGlobal]\n' >> config.gcfg"
sudo sh -c "printf '\tCreateDatabaseIfNotExists = true\n' >> config.gcfg"
sudo sh -c "printf '\tNastyString = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tNastyStringToReplace = \"\"\n' >> config.gcfg"
sudo sh -c "printf '\tHostcheckAlias = \"hostcheck\"\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDB \"telegraf\"]\n' >> config.gcfg"
sudo sh -c "printf '\tEnabled = true\n' >> config.gcfg"
sudo sh -c "printf '\tVersion = 1.0\n' >> config.gcfg"
sudo sh -c "printf '\tAddress = \"http://10.0.123.2:8086\"\n' >> config.gcfg"
sudo sh -c "printf '\tArguments = \"precision=ms&u=telegraf&p=password&db=telegraf\"\n' >> config.gcfg"
sudo sh -c "printf '\tStopPullingDataIfDown = true\n' >> config.gcfg"
sudo sh -c "printf '\n' >> config.gcfg"
sudo sh -c "printf '[InfluxDB \"fast\"]\n' >> config.gcfg"
sudo sh -c "printf '\tEnabled = false\n' >> config.gcfg"
sudo sh -c "printf '\tVersion = 1.0\n' >> config.gcfg"
sudo sh -c "printf '\tAddress = \"http://127.0.0.1:8086\"\n' >> config.gcfg"
sudo sh -c "printf '\tArguments = \"precision=ms&u=root&p=root&db=fast\"\n' >> config.gcfg"
sudo sh -c "printf '\tStopPullingDataIfDown = false\n' >> config.gcfg"

#Iniciamos nagflux
sudo systemctl start nagflux.service

#Configuracion de Nagios command
sudo sh -c "sed -i 's/^process_performance_data=0/process_performance_data=1/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file=/host_perfdata_file=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_template=.*/host_perfdata_file_template=DATATYPE::HOSTPERFDATA\\\\tTIMET::\$TIMET\$\\\\tHOSTNAME::\$HOSTNAME\$\\\\tHOSTPERFDATA::\$HOSTPERFDATA\$\\\\tHOSTCHECKCOMMAND::\$HOSTCHECKCOMMAND\$/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_mode=/host_perfdata_file_mode=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_processing_interval=.*/host_perfdata_file_processing_interval=15/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#host_perfdata_file_processing_command=.*/host_perfdata_file_processing_command=process-host-perfdata-file-nagflux/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file=/service_perfdata_file=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_template=.*/service_perfdata_file_template=DATATYPE::SERVICEPERFDATA\\\\tTIMET::\$TIMET\$\\\\tHOSTNAME::\$HOSTNAME\$\\\\tSERVICEDESC::\$SERVICEDESC\$\\\\tSERVICEPERFDATA::\$SERVICEPERFDATA\$\\\\tSERVICECHECKCOMMAND::\$SERVICECHECKCOMMAND\$/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_mode=/service_perfdata_file_mode=/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_processing_interval=.*/service_perfdata_file_processing_interval=15/g' /usr/local/nagios/etc/nagios.cfg"
sudo sh -c "sed -i 's/^#service_perfdata_file_processing_command=.*/service_perfdata_file_processing_command=process-service-perfdata-file-nagflux/g' /usr/local/nagios/etc/nagios.cfg"

sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo 'define command {' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_name    process-host-perfdata-file-nagflux' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_line    /bin/mv /usr/local/nagios/var/host-perfdata /usr/local/nagios/var/spool/nagfluxperfdata/\$TIMET\$.perfdata.host' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    }' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo 'define command {' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_name    process-service-perfdata-file-nagflux' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    command_line    /bin/mv /usr/local/nagios/var/service-perfdata /usr/local/nagios/var/spool/nagfluxperfdata/\$TIMET\$.perfdata.service' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '    }' >> /usr/local/nagios/etc/objects/commands.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/commands.cfg"

#Reiniciamos servicio
sudo systemctl restart nagios.service

#Nagios core integracion con grafana
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo 'define host {' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   name       host-grafana' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   action_url http://10.0.123.2:3000/dashboard/script/histou.js?host=\$HOSTNAME\$' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   register   0' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '}' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo 'define service {' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   name       service-grafana' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   action_url http://10.0.123.2:3000/dashboard/script/histou.js?host=\$HOSTNAME\$&service=\$SERVICEDESC\$' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '   register   0' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '}' >> /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "echo '' >> /usr/local/nagios/etc/objects/templates.cfg"

sudo sh -c "sed -i '/name.*generic-host/a\        use                             host-grafana' /usr/local/nagios/etc/objects/templates.cfg"
sudo sh -c "sed -i '/name.*generic-service/a\        use                             service-grafana' /usr/local/nagios/etc/objects/templates.cfg"

#Reiniciamos Nagios 

sudo systemctl restart nagios.service

