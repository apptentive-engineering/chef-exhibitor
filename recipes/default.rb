#
# Cookbook Name:: apptentive_exhibitor
# Recipe:: default
#
# The MIT License (MIT)
#
# Copyright (c) 2015 Apptentive, Inc.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

include_recipe "apptentive_gradle::default"
include_recipe "apptentive_zookeeper::default"

package "java-1.7.0-openjdk-devel"

version_path = "#{node["exhibitor"]["versions_dir"]}/#{node["exhibitor"]["version"]}"

%w[libs config bin].each do |dir|
  directory "#{version_path}/#{dir}" do
    recursive true
  end
end

template "#{version_path}/.build.gradle" do
  source "exhibitor.gradle.erb"
  backup false
  notifies :run, "execute[exhibitor gradle]"
end

execute "exhibitor gradle" do
  command "#{node["gradle"]["current_path"]}/bin/gradle -b .build.gradle copyLibs"
  cwd version_path
  action :nothing
end

link node["exhibitor"]["current_path"] do
  to version_path
end

cookbook_file "exhibitor" do
  path "#{version_path}/bin/exhibitor"
  mode 0755
end

raise if node["exhibitor"]["s3_bucket"].nil?

template "#{version_path}/config/default.properties" do
  source "default.properties.erb"
  backup false
  notifies :restart, "runit_service[exhibitor]"
end

runit_service "exhibitor" do
  env({
    "S3_BUCKET" => node["exhibitor"]["s3_bucket"],
    "S3_PREFIX" => node["exhibitor"]["s3_prefix"],
    "HOSTNAME"  => node["ipaddress"],
  })
  default_logger true
  subscribes :restart, "link[#{node["zookeeper"]["current_path"]}"
end
