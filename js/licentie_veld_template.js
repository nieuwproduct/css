document.addEventListener("DOMContentLoaded", function () {
    const veldTypeField = document.getElementById("id_veld_type");
    const booleanFieldContainer = document.querySelector(".field-default_boolean");
    const integerFieldContainer = document.querySelector(".field-default_integer");
    const textFieldContainer = document.querySelector(".field-default_text");

    const booleanField = document.getElementById("id_default_boolean");
    const integerField = document.getElementById("id_default_integer");
    const textField = document.getElementById("id_default_text");

    const groupField = document.getElementById("id_group");  // New group field
    const groupFieldContainer = document.querySelector(".field-group");  // Group container

    function updateFields() {
        const veldType = veldTypeField.value;

        // Show or hide the group field if needed (optional)
        if (groupField) {
            groupFieldContainer.style.display = "block";
        }

        // Show or hide field containers based on veld_type
        if (veldType === "boolean") {
            booleanFieldContainer.style.display = "block";
            booleanFieldContainer.classList.remove("hidden");
            integerFieldContainer.style.display = "none";
            textFieldContainer.style.display = "none";

            // Ensure the correct field types are visible
            booleanField.type = "checkbox";
            integerField.type = "hidden";
            textField.type = "hidden";
        } else if (veldType === "integer") {
            booleanFieldContainer.style.display = "none";
            integerFieldContainer.style.display = "block";
            integerFieldContainer.classList.remove("hidden");
            textFieldContainer.style.display = "none";

            booleanField.type = "hidden";
            integerField.type = "number";
            textField.type = "hidden";
        } else if (veldType === "text") {
            booleanFieldContainer.style.display = "none";
            integerFieldContainer.style.display = "none";
            textFieldContainer.style.display = "block";
            textFieldContainer.classList.remove("hidden");

            booleanField.type = "hidden";
            integerField.type = "hidden";
            textField.type = "text";
        } else {
            // Hide all fields if no veld_type is chosen
            booleanFieldContainer.style.display = "none";
            integerFieldContainer.style.display = "none";
            textFieldContainer.style.display = "none";

            booleanField.type = "hidden";
            integerField.type = "hidden";
            textField.type = "hidden";
        }
    }

    veldTypeField.addEventListener("change", updateFields);
    updateFields();  // Check the field type initially
});
