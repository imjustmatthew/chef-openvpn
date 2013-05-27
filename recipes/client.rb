
package "openvpn"

# create openvpn user and group
user "openvpn"
group "openvpn" do
  members ["openvpn"]
end

directory "/var/log/openvpn" do
  owner "root"
  group "root"
  mode 00755
end

# setup each client_config
configurtions = node[:openvpn][:client_configs]
configurtions.each do |config_name,config|

  # user_name required for given vpn server/config
  user_name = config[:user_name]
  
  begin
    #First, try loading the crypto materials from an encrypted databag
    data_bag_item = Chef::EncryptedDataBagItem.load("openvpn-"+config_name, user_name)
    file "/etc/openvpn/#{config_name}-#{user_name}-ca.crt" do
      content data_bag_item[:ca]
      owner "root"
      group "openvpn"
      mode 00660
    end
    if (config[:auth][:type] == "cert") or (config[:auth][:type] == "cert_passwd")
      file "/etc/openvpn/#{config_name}-#{user_name}.crt" do
        content data_bag_item[:cert]
        owner "root"
        group "openvpn"
        mode 00660
      end
      file "/etc/openvpn/#{config_name}-#{user_name}.key" do
        content data_bag_item[:key]
        owner "root"
        group "openvpn"
        mode 00660
      end
    end
    file "/etc/openvpn/#{config_name}-#{user_name}.conf" do
      content data_bag_item[:conf]
      owner "root"
      group "openvpn"
      mode 00660
    end
  rescue #No data bag? Missing items? Use files sourced from this cookbook or the specified provider instead
    cookbook_file "/etc/openvpn/#{config_name}-#{user_name}-ca.crt" do
      source "#{config_name}-ca.crt"
      owner "root"
      group "openvpn"
      mode 00660
      cookbook config[:file_cookbook] if config[:file_cookbook]
    end

    if (config[:auth][:type] == "cert") or (config[:auth][:type] == "cert_passwd")
      cookbook_file "/etc/openvpn/#{config_name}-#{user_name}.crt" do
        source "#{config_name}-#{user_name}.crt"
        owner "root"
        group "openvpn"
        mode 00660
        cookbook config[:file_cookbook] if config[:file_cookbook]
      end

      cookbook_file "/etc/openvpn/#{config_name}-#{user_name}.key" do
        source "#{config_name}-#{user_name}.key"
        owner "root"
        group "openvpn"
        mode 00660
        cookbook config[:file_cookbook] if config[:file_cookbook]
      end
    end

    cookbook_file "/etc/openvpn/#{config_name}-#{user_name}.conf" do
      source "#{config_name}-#{user_name}.conf"
      owner "root"
      group "openvpn"
      mode 00660
      cookbook config[:file_cookbook] if config[:file_cookbook]
    end
  end
end

service "openvpn" do
  action [:enable, :start]
end
