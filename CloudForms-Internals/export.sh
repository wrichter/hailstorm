#Script used to export data from a live environment
#As described in https://github.com/rhtconsulting/cfme-rhconsulting-scripts

BUILDDIR=/tmp/exports
rm -fR ${BUILDDIR}
mkdir -p ${BUILDDIR}/{provision_dialogs,service_dialogs,service_catalogs,roles,tags,buttons,customization_templates,reports,policies,alerts,alertsets,widgets}
mkdir -p ${BUILDDIR}/{service_catalogs,dialogs,roles,tags,buttons,customization_templates,policies,alerts,alertsets,widgets,miq_ae_datastore,scanitems,scriptsrc}


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

cd /var/www/miq/vmdb
bin/rake rhconsulting:miq_schedules:export[${BUILDDIR}/schedules]
bin/rake rhconsulting:provision_dialogs:export[${BUILDDIR}/provision_dialogs]
bin/rake rhconsulting:service_dialogs:export[${BUILDDIR}/service_dialogs]
bin/rake rhconsulting:service_catalogs:export[${BUILDDIR}/service_catalogs]
bin/rake rhconsulting:roles:export[${BUILDDIR}/roles/roles.yml]
bin/rake rhconsulting:tags:export[${BUILDDIR}/tags/tags.yml]
bin/rake rhconsulting:buttons:export[${BUILDDIR}/buttons/buttons.yml]
bin/rake rhconsulting:customization_templates:export[${BUILDDIR}/customization_templates/customization_templates.yml]
bin/rake rhconsulting:orchestration_templates:export[${BUILDDIR}/orchestration_templates]
bin/rake rhconsulting:miq_policies:export[${BUILDDIR}/policies]
bin/rake rhconsulting:miq_alerts:export[${BUILDDIR}/alerts]
bin/rake rhconsulting:miq_alertsets:export[${BUILDDIR}/alertsets]
bin/rake rhconsulting:miq_widgets:export[${BUILDDIR}/widgets]
bin/rake rhconsulting:miq_scanprofiles:export[${BUILDDIR}/scanitems]
bin/rake rhconsulting:miq_scriptsrc:export[${BUILDDIR}/scriptsrc]
bin/rake "rhconsulting:miq_ae_datastore:export[${DOMAIN_EXPORT}, ${BUILDDIR}/miq_ae_datastore]"


sudo -E -i -u root sh -c "cd /var/www/miq/vmdb; rake evm:automate:backup BACKUP_ZIP_FILE=/tmp/exports/automate.zip"
