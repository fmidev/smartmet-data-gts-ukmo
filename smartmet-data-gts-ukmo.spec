%define smartmetroot /smartmet

Name:           smartmet-data-gts-ukmo
Version:        18.12.10
Release:        2%{?dist}.fmi
Summary:        SmartMet Data UKMO Global Model from GTS
Group:          System Environment/Base
License:        MIT
URL:            https://github.com/fmidev/smartmet-data-gts-ukmo
BuildRoot:      %{_tmppath}/%{name}-%{version}-%{release}-root-%(%{__id_u} -n)
BuildArch:	noarch

Requires:	smartmet-qdtools
Requires:	lbzip2
Requires:	vsftpd


%description
TODO

%prep

%build

%pre

%install
rm -rf $RPM_BUILD_ROOT
mkdir $RPM_BUILD_ROOT
cd $RPM_BUILD_ROOT

mkdir -p .%{smartmetroot}/cnf/cron/{cron.d,cron.hourly}
mkdir -p .%{smartmetroot}/cnf/data
mkdir -p .%{smartmetroot}/tmp/data
mkdir -p .%{smartmetroot}/logs/data
mkdir -p .%{smartmetroot}/run/data/ukmo_gts/{bin,cnf}
mkdir -p .%{smartmetroot}/data/incoming/gts/ukmo

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.d/ukmo-gts.cron <<EOF
# Run every hour to test if new data is available
5 * * * * /smartmet/run/data/ukmo_gts/bin/doukmo.sh
EOF

cat > %{buildroot}%{smartmetroot}/cnf/cron/cron.hourly/clean_data_gts_ukmo <<EOF
#!/bin/sh
# Clean UKMO data
cleaner -maxfiles 4 '_ukmo_.*_surface.sqd' /smartmet/data/ukmo
cleaner -maxfiles 4 '_ukmo_.*_pressure.sqd' /smartmet/data/ukmo
cleaner -maxfiles 4 '_ukmo_.*_surface.sqd' /smartmet/editor/in
cleaner -maxfiles 4 '_ukmo_.*_pressure.sqd' /smartmet/editor/in

# Clean incoming SYNOP data older than 1 day (24 * 60 = 1440 min)
find /smartmet/data/incoming/gts/ukmo/ -type f -mmin +1440 -delete
EOF

cat > %{buildroot}%{smartmetroot}/cnf/data/ukmo-gts.cnf <<EOF
AREA="world"
EOF

install -m 755 %_topdir/SOURCES/smartmet-data-gts-ukmo/doukmo.sh %{buildroot}%{smartmetroot}/run/data/ukmo_gts/bin/

%post

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,smartmet,smartmet,-)
%config(noreplace) %{smartmetroot}/cnf/data/ukmo-gts.cnf
%config(noreplace) %{smartmetroot}/cnf/cron/cron.d/ukmo-gts.cron
%config(noreplace) %attr(0755,smartmet,smartmet) %{smartmetroot}/cnf/cron/cron.hourly/clean_data_gts_ukmo
%attr(2775,smartmet,gts)  %dir %{smartmetroot}/data/incoming/gts/ukmo
%{smartmetroot}/*

%changelog
* Mon Dec 10 2018 Mikko Rauhala <mikko.rauhala@fmi.fi> 18.12.10-1.el7.fmi
- Initial version
