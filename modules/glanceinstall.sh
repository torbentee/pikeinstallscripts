#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack PIKE for Ubuntu 16.04lts
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# First, we source our config file and verify that some important proccess are 
# already completed.
#

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't Access my config file. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "DB Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "DB Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Keystone Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "Keystone Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/glance-installed ]
then
	echo ""
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi


echo ""
echo "Installing GLANCE Packages"


#
# We proceed to install Glance Packages non interactivelly
#

export DEBIAN_FRONTEND=noninteractive

DEBIAN_FRONTEND=noninteractive aptitude -y install glance glance-api glance-common glance-registry

echo "Done"
echo ""

#
# We silently stop glance services prior to configuration
#

stop glance-registry >/dev/null 2>&1
stop glance-api >/dev/null 2>&1
stop glance-registry >/dev/null 2>&1
stop glance-api >/dev/null 2>&1
systemctl stop glance-registry >/dev/null 2>&1
systemctl stop glance-api >/dev/null 2>&1
systemctl stop glance-registry >/dev/null 2>&1
systemctl stop glance-api >/dev/null 2>&1

source $keystone_admin_rc_file

echo ""
echo "Configuring Glance"

sync
sleep 5
sync

#
# Using python based tools, we proceed to configure glance services
#

crudini --set /etc/glance/glance-api.conf DEFAULT debug False
crudini --set /etc/glance/glance-api.conf glance_store default_store file
crudini --set /etc/glance/glance-api.conf glance_store stores "file,http"
crudini --set /etc/glance/glance-api.conf glance_store filesystem_store_datadir /var/lib/glance/images/
crudini --set /etc/glance/glance-api.conf DEFAULT bind_host $glancehost
crudini --set /etc/glance/glance-api.conf DEFAULT bind_port 9292
crudini --set /etc/glance/glance-api.conf DEFAULT log_file /var/log/glance/api.log
crudini --set /etc/glance/glance-api.conf DEFAULT backlog 4096
crudini --set /etc/glance/glance-api.conf DEFAULT use_syslog False
 
 
case $dbflavor in
"mysql")
	crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://$glancedbuser:$glancedbpass@$dbbackendhost:$mysqldbport/$glancedbname
	crudini --set /etc/glance/glance-registry.conf database connection mysql+pymysql://$glancedbuser:$glancedbpass@$dbbackendhost:$mysqldbport/$glancedbname
	;;
"postgres")
	crudini --set /etc/glance/glance-api.conf database connection postgresql+psycopg2://$glancedbuser:$glancedbpass@$dbbackendhost:$psqldbport/$glancedbname
	crudini --set /etc/glance/glance-registry.conf database connection postgresql+psycopg2://$glancedbuser:$glancedbpass@$dbbackendhost:$psqldbport/$glancedbname
	;;
esac
 
 
# glanceworkers=`grep processor.\*: /proc/cpuinfo |wc -l`
 
crudini --set /etc/glance/glance-api.conf DEFAULT workers $glanceworkers
crudini --set /etc/glance/glance-api.conf DEFAULT registry_host $glancehost
crudini --set /etc/glance/glance-api.conf DEFAULT registry_port 9191
crudini --set /etc/glance/glance-api.conf DEFAULT registry_client_protocol http

crudini --set /etc/glance/glance-api.conf DEFAULT delayed_delete False
crudini --set /etc/glance/glance-api.conf DEFAULT scrub_time 43200
 
crudini --set /etc/glance/glance-api.conf database retry_interval 10
crudini --set /etc/glance/glance-api.conf database idle_timeout 3600
crudini --set /etc/glance/glance-api.conf database min_pool_size 1
crudini --set /etc/glance/glance-api.conf database max_pool_size 10
crudini --set /etc/glance/glance-api.conf database max_retries 100
crudini --set /etc/glance/glance-api.conf database pool_timeout 10

crudini --set /etc/glance/glance-registry.conf database retry_interval 10
crudini --set /etc/glance/glance-registry.conf database idle_timeout 3600
crudini --set /etc/glance/glance-registry.conf database min_pool_size 1
crudini --set /etc/glance/glance-registry.conf database max_pool_size 10
crudini --set /etc/glance/glance-registry.conf database max_retries 100
crudini --set /etc/glance/glance-registry.conf database pool_timeout 10

if [ $ceilometerinstall == "yes" ]
then
	crudini --set /etc/glance/glance-api.conf DEFAULT notification_driver messagingv2
	crudini --set /etc/glance/glance-registry.conf DEFAULT notification_driver messagingv2
        crudini --set /etc/glance/glance-api.conf oslo_messaging_notifications driver messagingv2
        crudini --set /etc/glance/glance-registry.conf oslo_messaging_notifications driver messagingv2	
fi

crudini --set /etc/glance/glance-api.conf DEFAULT transport_url rabbit://$brokeruser:$brokerpass@$messagebrokerhost:5672/$brokervhost 
crudini --set /etc/glance/glance-api.conf DEFAULT notifier_strategy rabbitmq
# Finally, deprecated !
# crudini --set /etc/glance/glance-api.conf DEFAULT rabbit_host $messagebrokerhost
# crudini --set /etc/glance/glance-api.conf DEFAULT rpc_backend rabbit
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_password $brokerpass
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_userid $brokeruser
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_port 5672
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_use_ssl false
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_max_retries 0
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_retry_interval 1
# crudini --set /etc/glance/glance-api.conf oslo_messaging_rabbit rabbit_ha_queues false
 
 
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $keystonehost:11211
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/glance/glance-api.conf keystone_authtoken username $glanceuser
crudini --set /etc/glance/glance-api.conf keystone_authtoken password $glancepass
 
crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone
crudini --set /etc/glance/glance-registry.conf paste_deploy flavor keystone
 
 
crudini --set /etc/glance/glance-registry.conf DEFAULT debug False
crudini --set /etc/glance/glance-registry.conf DEFAULT bind_host $glancehost
crudini --set /etc/glance/glance-registry.conf DEFAULT bind_port 9191
crudini --set /etc/glance/glance-registry.conf DEFAULT log_file /var/log/glance/registry.log
crudini --set /etc/glance/glance-registry.conf DEFAULT backlog 4096
crudini --set /etc/glance/glance-registry.conf DEFAULT use_syslog False
 
crudini --set /etc/glance/glance-registry.conf DEFAULT sql_idle_timeout 3600
crudini --set /etc/glance/glance-registry.conf DEFAULT api_limit_max 1000
crudini --set /etc/glance/glance-registry.conf DEFAULT limit_param_default 25
 
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/glance/glance-registry.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-registry.conf keystone_authtoken memcached_servers $keystonehost:11211
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/glance/glance-registry.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/glance/glance-registry.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/glance/glance-registry.conf keystone_authtoken username $glanceuser
crudini --set /etc/glance/glance-registry.conf keystone_authtoken password $glancepass
 
crudini --set /etc/glance/glance-cache.conf DEFAULT debug False
crudini --set /etc/glance/glance-cache.conf DEFAULT log_file /var/log/glance/image-cache.log
crudini --set /etc/glance/glance-cache.conf DEFAULT image_cache_dir /var/lib/glance/image-cache/
crudini --set /etc/glance/glance-cache.conf DEFAULT image_cache_stall_time 86400
crudini --set /etc/glance/glance-cache.conf DEFAULT image_cache_invalid_entry_grace_period 3600
crudini --set /etc/glance/glance-cache.conf DEFAULT image_cache_max_size 10737418240
crudini --set /etc/glance/glance-cache.conf DEFAULT registry_host $glancehost
crudini --set /etc/glance/glance-cache.conf DEFAULT registry_port 9191
crudini --set /etc/glance/glance-cache.conf DEFAULT admin_tenant_name $keystoneservicestenant
crudini --set /etc/glance/glance-cache.conf DEFAULT admin_user $glanceuser
crudini --set /etc/glance/glance-cache.conf DEFAULT filesystem_store_datadir /var/lib/glance/images/
 

mkdir -p /var/lib/glance/image-cache/
chown -R glance.glance /var/lib/glance/image-cache

echo "Done"

#
# We proceed to provision/update glance database
#

rm -f /var/lib/glance/glance.sqlite

echo ""
echo "Provisioning Glance DB"
echo ""
su -s /bin/sh -c "glance-manage db_sync" glance

sync
sleep 5
sync

#
# Here, we apply IPTABLES rules and start/enable glance services
#

echo ""
# echo "Applying IPTABLES rules"
# iptables -A INPUT -p tcp -m multiport --dports 9292 -j ACCEPT
# /etc/init.d/netfilter-persistent save
echo "Done"
echo ""

echo ""
echo "Cleaning UP App logs"

for mylog in `ls /var/log/glance/*.log`; do echo "" > $mylog;done

echo "Done"
echo ""

echo "Starting GLANCE"

systemctl start glance-registry
systemctl start glance-api
systemctl enable glance-registry
systemctl enable glance-api


sleep 5

systemctl restart glance-registry
sleep 2
systemctl restart glance-api
sleep 2

#
# If we select the option to use swift as a storage backend for glance, then
# we apply the proper configuration and restart glance services
#

if [ $glance_use_swift == "yes" ]
then
        if [ -f /etc/openstack-control-script-config/swift-installed ]
        then
		echo "Configuring Glance to use SWIFT as storage backend"
                crudini --set /etc/glance/glance-api.conf glance_store default_store swift
		crudini --set /etc/glance/glance-api.conf glance_store default_swift_reference ref1
                crudini --set /etc/glance/glance-api.conf glance_store swift_store_create_container_on_put True
                crudini --set /etc/glance/glance-api.conf glance_store swift_store_auth_version 3
                crudini --set /etc/glance/glance-api.conf glance_store swift_store_container glance
		crudini --set /etc/glance/glance-api.conf glance_store swift_store_config_file "/etc/glance/glance-swift.conf"
                crudini --set /etc/glance/glance-cache.conf glance_store default_store swift
		crudini --set /etc/glance/glance-cache.conf glance_store default_swift_reference ref1
                crudini --set /etc/glance/glance-cache.conf glance_store swift_store_create_container_on_put True
                crudini --set /etc/glance/glance-cache.conf glance_store swift_store_auth_version 3
                crudini --set /etc/glance/glance-cache.conf glance_store swift_store_container glance
		crudini --set /etc/glance/glance-cache.conf glance_store swift_store_config_file "/etc/glance/glance-swift.conf"
		echo "" >> /etc/glance/glance-swift.conf
		crudini --set /etc/glance/glance-swift.conf ref1 user $keystoneservicestenant:$swiftuser
		crudini --set /etc/glance/glance-swift.conf ref1 key $swiftpass
		crudini --set /etc/glance/glance-swift.conf ref1 auth_version 3
		crudini --set /etc/glance/glance-swift.conf ref1 user_domain_name $keystonedomain
		crudini --set /etc/glance/glance-swift.conf ref1 project_domain_name $keystonedomain
		crudini --set /etc/glance/glance-swift.conf ref1 auth_address http://$keystonehost:5000/v3
		chown glance.glance /etc/glance/glance-swift.conf
                echo ""
                echo "Stopping Glance"
                echo ""

                systemctl stop glance-registry
                systemctl stop glance-api

                sync
                sleep 5
                sync

                echo ""
                echo "Stargting GLANCE with Swift as a storage backend"
                echo ""

                systemctl start glance-api
                systemctl start glance-registry
        fi
fi

#
# We test if glance was properlly installed, and if not, we fail and make the main installer to stop
# further proccessing.
#

testglance=`dpkg -l glance-api 2>/dev/null|tail -n 1|grep -ci ^ii`
if [ $testglance == "0" ]
then
	echo ""
	echo "Glance Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/glance-installed
	date > /etc/openstack-control-script-config/glance
fi

echo ""
echo "Glance Installed"
echo ""

echo ""
echo "Loading extra metadata"
#glance-manage db_load_metadefs
su -s /bin/sh -c "glance-manage db_load_metadefs" glance
echo ""

#
# Finally, if we choose to do it, we provision Cirros TEST Images
#

if [ $glancecirroscreate == "yes" ]
then
	echo ""
	echo "Adding CIRROS Images to GLANCE"
	echo ""
	source $keystone_fulladmin_rc_file

	sync
	sleep 10
	openstack image list

	sync
	sleep 10
	sync

	openstack image create "Cirros-0.3.5-32" \
		--disk-format qcow2 \
		--public \
		--container-format bare \
		--project $keystoneadminuser \
		--protected \
		--file ./libs/cirros/cirros-0.3.5-i386-disk.img

	sync
	sleep 10
	sync

	openstack image create "Cirros-0.3.5-64" \
		--disk-format qcow2 \
		--public \
		--container-format bare \
		--project $keystoneadminuser \
		--protected \
		--file ./libs/cirros/cirros-0.3.5-x86_64-disk.img

	sync
	sleep 5
	sync

	openstack image list

	echo ""
	echo "Cirros Images added to GLANCE"
	echo ""
fi


