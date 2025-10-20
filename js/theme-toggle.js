document.addEventListener('DOMContentLoaded', () => {
    const themeToggleBtn = document.getElementById('theme-toggle');
    if (!themeToggleBtn) {
        return;
    }
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
        document.body.classList.add('dark-mode');
        const navbar = document.querySelector('.navbar');
        if (navbar) {
            navbar.classList.add('dark-mode');
        }
        document.querySelectorAll('.card').forEach(card => card.classList.add('dark-mode'));
        document.querySelectorAll('.table').forEach(table => table.classList.add('dark-mode'));
        document.querySelectorAll('.btn-outline-secondary').forEach(btn => btn.classList.add('dark-mode'));
        const mainElement = document.querySelector('main');
        if (mainElement) {
            mainElement.classList.add('dark-mode');
        }
        themeToggleBtn.innerHTML = '<i class="bi bi-sun-fill"></i>'; // Change icon to sun
        localStorage.setItem('theme', 'dark');
    }

    function enableLightMode() {
        document.body.classList.remove('dark-mode');
        const navbar = document.querySelector('.navbar');
        if (navbar) {
            navbar.classList.remove('dark-mode');
        }
        document.querySelectorAll('.card').forEach(card => card.classList.remove('dark-mode'));
        document.querySelectorAll('.table').forEach(table => table.classList.remove('dark-mode'));
        document.querySelectorAll('.btn-outline-secondary').forEach(btn => btn.classList.remove('dark-mode'));
        const mainElement = document.querySelector('main');
        if (mainElement) {
            mainElement.classList.remove('dark-mode');
        }
        themeToggleBtn.innerHTML = '<i class="bi bi-moon-fill"></i>'; // Change icon to moon
        localStorage.setItem('theme', 'light');
    }
});
