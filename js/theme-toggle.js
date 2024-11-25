document.addEventListener('DOMContentLoaded', () => {
    const themeToggleBtn = document.getElementById('theme-toggle');
    const currentTheme = localStorage.getItem('theme') || 'light';

    // Apply the saved theme on load
    if (currentTheme === 'dark') {
        enableDarkMode();
    } else {
        enableLightMode();
    }

    // Toggle theme on button click
    themeToggleBtn.addEventListener('click', () => {
        if (document.body.classList.contains('dark-mode')) {
            enableLightMode();
        } else {
            enableDarkMode();
        }
    });

    function enableDarkMode() {
        // Add dark-mode to body and navbar
        document.body.classList.add('dark-mode');
        document.querySelector('.navbar').classList.add('dark-mode');

        // Toggle dark-mode on all card elements
        document.querySelectorAll('.card').forEach(card => card.classList.add('dark-mode'));
        
        // Toggle dark-mode on card headers
        document.querySelectorAll('.card-header').forEach(header => {
            header.classList.add('dark-mode');
            header.classList.remove('bg-primary', 'text-white'); // Remove Bootstrap light classes
            header.style.backgroundColor = '#343a40'; // Optional: Set manual dark background
            header.style.color = '#f8f9fa'; // Optional: Set manual dark text
        });

        // Toggle dark-mode on table elements
        document.querySelectorAll('.table').forEach(table => table.classList.add('dark-mode'));
        
        // Toggle dark-mode for th and td elements inside tables
        document.querySelectorAll('.table th, .table td').forEach(cell => {
            cell.classList.add('dark-mode');
            cell.style.borderColor = '#454d55'; // Optional: Set dark border color for table cells
        });

        // Apply dark mode to input, textarea, and select fields
        document.querySelectorAll('input, textarea, select').forEach(field => field.classList.add('dark-mode'));

        // Toggle dark-mode on containers and rows
        document.querySelectorAll('.container, .row').forEach(element => element.classList.add('dark-mode'));

        // Change the icon on the toggle button
        themeToggleBtn.innerHTML = '<i class="bi bi-sun-fill"></i>';
        
        // Save dark mode setting in localStorage
        localStorage.setItem('theme', 'dark');
    }

    function enableLightMode() {
        // Remove dark-mode from body and navbar
        document.body.classList.remove('dark-mode');
        document.querySelector('.navbar').classList.remove('dark-mode');

        // Remove dark-mode from card elements
        document.querySelectorAll('.card').forEach(card => card.classList.remove('dark-mode'));

        // Remove dark-mode from card headers and restore original Bootstrap styles
        document.querySelectorAll('.card-header').forEach(header => {
            header.classList.remove('dark-mode');
            header.classList.add('bg-primary', 'text-white'); // Re-add Bootstrap light classes
            header.style.backgroundColor = ''; // Clear manual background styles
            header.style.color = ''; // Clear manual text color styles
        });

        // Remove dark-mode from table elements
        document.querySelectorAll('.table').forEach(table => table.classList.remove('dark-mode'));

        // Remove dark-mode from th and td elements inside tables
        document.querySelectorAll('.table th, .table td').forEach(cell => {
            cell.classList.remove('dark-mode');
            cell.style.borderColor = ''; // Reset to default border color
        });

        // Remove dark-mode from input, textarea, and select fields
        document.querySelectorAll('input, textarea, select').forEach(field => field.classList.remove('dark-mode'));

        // Remove dark-mode from containers and rows
        document.querySelectorAll('.container, .row').forEach(element => element.classList.remove('dark-mode'));

        // Change the icon on the toggle button
        themeToggleBtn.innerHTML = '<i class="bi bi-moon-fill"></i>';
        
        // Save light mode setting in localStorage
        localStorage.setItem('theme', 'light');
    }
});
