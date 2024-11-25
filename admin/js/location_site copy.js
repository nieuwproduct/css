document.addEventListener('DOMContentLoaded', function () {
    const networkInput = document.querySelector('.network-input');
    const cidrInput = document.querySelector('.cidr-input');
    const gatewayField = document.querySelector('#id_gateway');
    const broadcastField = document.querySelector('#id_broadcast');
    const availableIpsField = document.querySelector('#id_available_ips');


    function updateAutoCalculatedFields() {
        var network = $('.network-input').val();
        var cidr = $('.cidr-input').val();
        
        if (network && cidr) {
            $.ajax({
                url: "{% url 'calculate_ip_range' %}",  // URL to handle the calculation
                type: 'GET',
                data: {
                    'network': network,
                    'cidr': cidr,
                },
                success: function(data) {
                    $('.gateway-input').val(data.gateway);
                    $('.broadcast-input').val(data.broadcast);
                    $('.available-ips-input').val(data.available_ips);
                }
            });
        }
    }

    // Trigger the function when network or CIDR changes
    $('.network-input, .cidr-input').on('input', function() {
        updateAutoCalculatedFields();
    });
    
    function calculateIpRange(network, cidr) {
        // Perform IP calculation logic (you might want to use a library for this, such as ipaddr.js)
        try {
            const net = new ipaddr.IPv4Network(`${network}/${cidr}`);
            const hosts = net.hosts();
            const broadcast = net.broadcastAddress;
            const gateway = hosts[hosts.length - 2];  // Second to last IP
            const availableIps = hosts.filter(ip => ip !== gateway).join(', ');

            gatewayField.value = gateway;
            broadcastField.value = broadcast;
            availableIpsField.value = availableIps;
        } catch (error) {
            gatewayField.value = '';  // Clear values if invalid
            broadcastField.value = '';
            availableIpsField.value = '';
        }
    }

    // Event listeners to trigger calculations when network or CIDR is changed
    networkInput.addEventListener('input', function () {
        if (networkInput.value && cidrInput.value) {
            calculateIpRange(networkInput.value, parseInt(cidrInput.value, 10));
        }
    });

    cidrInput.addEventListener('input', function () {
        if (networkInput.value && cidrInput.value) {
            calculateIpRange(networkInput.value, parseInt(cidrInput.value, 10));
        }
    });

    // Function to dynamically add network fields
    function addNetworkField() {
        const container = document.querySelector('#network-container');
        const newField = document.createElement('div');
        newField.innerHTML = `
            <input type="text" name="network[]" placeholder="Network Address" class="network-input"/>
            <input type="number" name="cidr[]" placeholder="CIDR" class="cidr-input"/>
            <button type="button" class="remove-network">Remove</button>
        `;
        container.appendChild(newField);

        // Add remove event listener
        newField.querySelector('.remove-network').addEventListener('click', function () {
            newField.remove();
        });
    }

    // Add initial remove functionality to existing fields
    document.querySelectorAll('.remove-network').forEach(button => {
        button.addEventListener('click', function () {
            button.parentElement.remove();
        });
    });

    // Add event listener to the 'Add Network' button
    document.querySelector('#add-network').addEventListener('click', function () {
        addNetworkField();
    });
});
