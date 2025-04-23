document.addEventListener('DOMContentLoaded', function () {
    var veldTypeSelect = document.getElementById('id_veld_type');

    function toggleFields() {
        var veldType = veldTypeSelect.value;
        var booleanField = document.getElementById('id_default_boolean').closest('.form-row');
        var integerField = document.getElementById('id_default_integer').closest('.form-row');
        var textField = document.getElementById('id_default_text').closest('.form-row');

        // Verberg of toon de velden afhankelijk van het geselecteerde veld_type
        if (veldType === 'boolean') {
            booleanField.style.display = '';
            integerField.style.display = 'none';
            textField.style.display = 'none';
        } else if (veldType === 'integer') {
            booleanField.style.display = 'none';
            integerField.style.display = '';
            textField.style.display = 'none';
        } else if (veldType === 'text') {
            booleanField.style.display = 'none';
            integerField.style.display = 'none';
            textField.style.display = '';
        } else {
            // Verberg alle velden als er geen veld_type is geselecteerd
            booleanField.style.display = 'none';
            integerField.style.display = 'none';
            textField.style.display = 'none';
        }
    }

    // Roep de functie op bij het laden van de pagina en bij wijziging van het veld_type
    toggleFields();
    veldTypeSelect.addEventListener('change', toggleFields);
});
