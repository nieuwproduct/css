console.log('location_filter.js loaded');

document.addEventListener('DOMContentLoaded', function() {
    const organizationField = document.getElementById('id_organization');
    const vlanField = document.getElementById('id_vlan');
    const networkField = document.getElementById('id_network');
    const gatewayField = document.getElementById('id_gateway');
    const broadcastField = document.getElementById('id_broadcast');
    const ip1Field = document.getElementById('id_ip_1');
    const ip2Field = document.getElementById('id_ip_2');
    const ip3Field = document.getElementById('id_ip_3');
    const ip4Field = document.getElementById('id_ip_4');
    const ip5Field = document.getElementById('id_ip_5');

    if (organizationField) {
        organizationField.addEventListener('change', function() {
            const organizationId = this.value;
            if (organizationId) {
                fetch(`/admin/vlanmanager/get_vlans/?organization=${organizationId}`)
                    .then(response => response.json())
                    .then(data => {
                        // Clear VLAN options
                        vlanField.innerHTML = '';

                        // Add new options
                        data.vlans.forEach(function(vlan) {
                            const option = document.createElement('option');
                            option.value = vlan.id;
                            option.textContent = vlan.name;
                            option.dataset.thirdOctet = vlan.third_octet;  // Store third octet in dataset
                            option.dataset.ipRangeStart = vlan.ip_range_start;  // Store IP range start
                            option.dataset.ipRangeEnd = vlan.ip_range_end;  // Store IP range end
                            vlanField.appendChild(option);
                        });

                        // Trigger a change event on the VLAN field to auto-fill other fields
                        vlanField.dispatchEvent(new Event('change'));
                    })
                    .catch(error => console.error('Error fetching VLANs:', error));
            } else {
                vlanField.innerHTML = '';  // Clear if no organization is selected
                networkField.value = '';
                gatewayField.value = '';
                broadcastField.value = '';
            }
        });
    }
    const macFields = document.querySelectorAll('input[id^="id_mac_"]');
    
    macFields.forEach(function(macField) {
        macField.addEventListener('input', function() {
            let value = macField.value.replace(/[^A-Fa-f0-9]/g, ''); // Remove non-hexadecimal characters
            if (value.length > 12) {
                value = value.slice(0, 12);  // Limit to 12 characters (6 pairs)
            }

            // Format as MM:MM:MM:SS:SS:SS
            value = value.toUpperCase().match(/.{1,2}/g)?.join(':') || value;
            macField.value = value;
        });
    });
    if (vlanField) {
        vlanField.addEventListener('change', function() {
            const selectedOption = vlanField.options[vlanField.selectedIndex];

            const thirdOctet = selectedOption.dataset.thirdOctet;
            const fourthOctetStart = selectedOption.dataset.ipRangeStart;
            const fourthOctetEnd = selectedOption.dataset.ipRangeEnd;

            if (thirdOctet !== undefined && fourthOctetStart !== undefined) {
                networkField.value = `10.249.${thirdOctet}.${fourthOctetStart}`;
                gatewayField.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 1}`;
                broadcastField.value = `10.249.${thirdOctet}.${fourthOctetEnd}`;
                ip1Field.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 2}`;
                ip2Field.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 3}`;
                ip3Field.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 4}`;
                ip4Field.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 5}`;
                ip5Field.value = `10.249.${thirdOctet}.${parseInt(fourthOctetStart) + 6}`;
            } else {
                console.error('Third or Fourth octet could not be determined.');
            }
        });
    }
});
