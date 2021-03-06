#
# Cookbook Name:: chef-mailcatcher
# Recipe:: default
#
# Copyright (C) 2015 SPINEN
#

# Install required dependencies
case node['platform_family']
when 'debian', 'ubuntu'
  %w(
    build-essential
    software-properties-common
    sqlite
    libsqlite3-dev
    make
    ruby-dev
    g++
  ).each do |deb|
    package deb
  end
when 'rhel', 'fedora', 'suse'
  # Install required dependencies
  %w(
    gcc
    gcc-c++
    sqlite-devel
    ruby-devel
  ).each do |yum|
    package yum
  end
end

# Install Ruby language if not exists in PATH
package 'ruby' do
  action :install
  not_if 'which ruby'
end
execute 'gem_system_update' do
  command 'gem update --system -N;sleep 2;gem update -N'
  not_if 'which mailcatcher'
end

# Install mailcatcher
gem_package 'mailcatcher' do
  version node['mailcatcher']['version'] if node['mailcatcher']['version']
end

# Create init scripts for Mailcatcher daemon.
case node['platform']
# upstart script for ubuntu machines
when 'ubuntu'
  template '/etc/init/mailcatcher.conf' do
    source 'mailcatcher.upstart.conf.erb'
    mode 0644
    notifies :restart, 'service[mailcatcher]', :immediately
  end
  service 'mailcatcher' do
    provider Chef::Provider::Service::Upstart
    supports restart: true
    action :start
  end
# sysv (or systemd for newer versions) script for debian
when 'debian'
  if node['platform_version'].to_f >= 8.0
    template '/etc/systemd/system/mailcatcher.service' do
      source 'mailcatcher.init.systemd.conf.erb'
      mode 0644
      notifies :start, 'service[mailcatcher]', :immediately
    end
    service 'mailcatcher' do
      provider Chef::Provider::Service::Systemd
      supports start: true, stop: true, status: true
      action :start
    end
    service 'mailcatcher' do
      provider Chef::Provider::Service::Systemd
      action :enable
    end
  else
    template '/etc/init.d/mailcatcher' do
      source 'mailcatcher.init.debian.conf.erb'
      mode 0744
      notifies :start, 'service[mailcatcher]', :immediately
    end
    service 'mailcatcher' do
      provider Chef::Provider::Service::Init
      supports start: true, stop: true, status: true
      action :start
    end
  end
# sysv script for centos and suse (needs to be tested on suse still)
when 'centos'
  template '/etc/init.d/mailcatcher' do
    source 'mailcatcher.init.redhat.conf.erb'
    mode 0744
    notifies :restart, 'service[mailcatcher]', :immediately
  end
  service 'mailcatcher' do
    provider Chef::Provider::Service::Init
    supports start: true, stop: true, status: true
    action :start
  end
# Systemd init scripts. Still broken.
when 'suse', 'fedora'
  template '/etc/systemd/system/mailcatcher.service' do
    source 'mailcatcher.init.systemd.conf.erb'
    mode 0644
    notifies :restart, 'service[mailcatcher]', :immediately
  end
  service 'mailcatcher' do
    provider Chef::Provider::Service::Systemd
    supports restart: true
    action :start
  end
end

include_recipe 'chef-mailcatcher::postfix' if node['mailcatcher']['use_postfix']
