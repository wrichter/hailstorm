#As described in https://github.com/rhtconsulting/cfme-rhconsulting-scripts

BUILDDIR=/tmp/exports
rm -fR ${BUILDDIR}
mkdir -p ${BUILDDIR}/{provision_dialogs,service_dialogs,service_catalogs,roles,tags,buttons,customization_templates,reports,policies,alerts,alertsets,widgets}


miqexport provision_dialogs /tmp/exports/provision_dialogs
miqexport service_dialogs /tmp/exports/service_dialogs
miqexport service_catalogs /tmp/exports/service_catalogs
miqexport roles /tmp/exports/roles
miqexport tags /tmp/exports/tags
miqexport buttons /tmp/exports/buttons
miqexport customization_templates /tmp/exports/customization_templates
miqexport reports /tmp/exports/reports
miqexport widgets /tmp/exports/widgets
miqexport alerts /tmp/exports/alerts
miqexport alertsets /tmp/exports/alertsets
miqexport policies /tmp/exports/policies

sudo -E -i -u root sh -c "cd /var/www/miq/vmdb; rake evm:automate:backup BACKUP_ZIP_FILE=/tmp/exports/automate.zip"
