#!/bin/bash
set -e

# Builds to run
BUILDS=("nvl-unified")

# XML snippet to inject. Adding vApp properties user-data, meta-data, to enable cloud-init.
PRODUCT_SECTION=$'    <ProductSection>
      <Info>Information about the installed software</Info>
      <Product>Ubuntu 24.04</Product>
      <Vendor>Ubuntu</Vendor>
      <Version>24.04</Version>
      <Property ovf:key="instance-id" ovf:type="string" ovf:userConfigurable="true" ovf:value="id-ovf">
          <Label>A Unique Instance ID for this instance</Label>
          <Description>Specifies the instance id.  This is required and used to determine if the machine should take "first boot" actions</Description>
      </Property>
      <Property ovf:key="hostname" ovf:type="string" ovf:userConfigurable="true" ovf:value="ubuntuguest">
          <Description>Specifies the hostname for the appliance</Description>
      </Property>
      <Property ovf:key="seedfrom" ovf:type="string" ovf:userConfigurable="true"> 
          <Label>Url to seed instance data from</Label>
          <Description>This field is optional, but indicates that the instance should \'seed\' user-data and meta-data from the given url.  If set to \'http://tinyurl.com/sm-\' is given, meta-data will be pulled from http://tinyurl.com/sm-meta-data and user-data from http://tinyurl.com/sm-user-data.  Leave this empty if you do not want to seed from a url.</Description>
      </Property>
      <Property ovf:key="public-keys" ovf:type="string" ovf:userConfigurable="true" ovf:value="">
          <Label>ssh public keys</Label>
          <Description>This field is optional, but indicates that the instance should populate the default user\'s \'authorized_keys\' with this value</Description>
      </Property>
      <Property ovf:key="user-data" ovf:type="string" ovf:userConfigurable="true" ovf:value="">
          <Label>Encoded user-data</Label>
          <Description>In order to fit into a xml attribute, this value is base64 encoded . It will be decoded, and then processed normally as user-data.</Description>
          <!--  The following represents \'#!/bin/sh\necho "hi world"\'
          ovf:value="IyEvYmluL3NoCmVjaG8gImhpIHdvcmxkIgo="
        -->
      </Property>
      <Property ovf:key="password" ovf:type="string" ovf:userConfigurable="true" ovf:value="">
          <Label>Default User\'s password</Label>
          <Description>If set, the default user\'s password will be set to this value to allow password based login.  The password will be good for only a single login.  If set to the string \'RANDOM\' then a random password will be generated, and written to the console.</Description>
      </Property>
      <Property ovf:key="network-config" ovf:type="string" ovf:userConfigurable="true">
          <Label>Encoded network-config</Label>
          <Description>This field is optional. The value for network-config has to be base64 encoded.</Description>
      </Property>
    </ProductSection>'

for BUILD in "${BUILDS[@]}"; do
    echo "Building $BUILD..."
    # packer build -force -only="$BUILD.vsphere-iso.$BUILD" -var "vm_name=$BUILD" -var-file variables.json .
    
    # Determine OVF name based on build name (mapped in build.pkr.hcl)
    case $BUILD in
        "nvl-unified") OVF_NAME="nvl-unified" ;;
    esac

    OVF_FILE="output/$OVF_NAME.ovf"
    
    if [ -f "$OVF_FILE" ]; then
        echo "Injecting vApp properties into $OVF_FILE..."
        # Escape newlines for sed
        ESCAPED_SECTION=$(echo "$PRODUCT_SECTION" | sed ':a;N;$!ba;s/\n/\\n/g')
        # Insert before <VirtualHardwareSection>
        sed -i "/<VirtualHardwareSection>/i $ESCAPED_SECTION" "$OVF_FILE"
        
        # Enable vApp transport via VMware Tools
        sed -i 's/<VirtualHardwareSection>/<VirtualHardwareSection ovf:transport="com.vmware.guestInfo">/' "$OVF_FILE"
        
        echo "Injection complete."

        echo "Packaging into OVA..."
        # Go to output directory to avoid path issues in tar
        pushd output > /dev/null
        
        # Create OVA (Order matters: OVF, VMDK) - Manifest excluded as OVF was modified
        tar -cvf "$OVF_NAME.ova" "$OVF_NAME.ovf" "$OVF_NAME"-disk*.vmdk
        rm *.mf
        popd > /dev/null
        echo "OVA created: output/$OVF_NAME.ova"
    else
        echo "Error: $OVF_FILE not found!"
        exit 1
    fi
done

echo "All builds complete."
