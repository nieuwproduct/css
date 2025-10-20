document.addEventListener('DOMContentLoaded', () => {
    const themeToggleBtn = document.getElementById('theme-toggle');
    if (!themeToggleBtn) return;

    const currentTheme = localStorage.getItem('theme') || 'light';
    if (currentTheme === 'dark') enableDarkMode();
    else enableLightMode();

    themeToggleBtn.addEventListener('click', () => {
        if (document.body.classList.contains('dark-mode')) {
            enableLightMode();
        } else {
            enableDarkMode();
        }
    });

    function styleNavbarForTheme(isDark) {
        const navbar = document.querySelector('.navbar');
        if (!navbar) return;
        navbar.classList.toggle('dark-mode', isDark);
        navbar.classList.toggle('navbar-dark', isDark);
        navbar.classList.toggle('bg-dark', isDark);
        navbar.classList.toggle('navbar-light', !isDark);
        navbar.classList.toggle('bg-white', !isDark);
    }

    function toggleElementCollection(selector, className, enable) {
        document.querySelectorAll(selector).forEach((el) => {
            el.classList.toggle(className, enable);
        });
    }

    function enableDarkMode() {
        document.body.classList.add('dark-mode', 'bg-dark', 'text-light');
        document.body.classList.remove('bg-light', 'text-dark');

        styleNavbarForTheme(true);

        const selectors = [
            '.card', '.table', '.btn-outline-secondary', '.accordion-item',
            '.accordion-button', '.accordion-body', '.modal-content',
            '.form-control', '.form-select', '.input-group-text',
            '.accordion', '.table-responsive'
        ];
        selectors.forEach(sel => toggleElementCollection(sel, 'dark-mode', true));

        // Force override for Bootstrap table-light
        document.querySelectorAll('.table-light').forEach(el => el.classList.remove('table-light'));

        // Make sure all <thead> and <tbody> inherit dark colors
        document.querySelectorAll('.table thead, .table tbody').forEach(el => el.classList.add('dark-mode'));

        const mainElement = document.querySelector('main');
        if (mainElement) mainElement.classList.add('dark-mode');

        themeToggleBtn.innerHTML = '<i class="bi bi-sun-fill"></i>';
        localStorage.setItem('theme', 'dark');
        document.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: 'dark' } }));
    }

    function enableLightMode() {
        document.body.classList.remove('dark-mode', 'bg-dark', 'text-light');
        document.body.classList.add('bg-light', 'text-dark');

        styleNavbarForTheme(false);

        const selectors = [
            '.card', '.table', '.btn-outline-secondary', '.accordion-item',
            '.accordion-button', '.accordion-body', '.modal-content',
            '.form-control', '.form-select', '.input-group-text',
            '.accordion', '.table-responsive'
        ];
        selectors.forEach(sel => toggleElementCollection(sel, 'dark-mode', false));

        // Reapply Bootstrap light table header class
        document.querySelectorAll('thead').forEach(el => el.classList.add('table-light'));

        const mainElement = document.querySelector('main');
        if (mainElement) mainElement.classList.remove('dark-mode');

        themeToggleBtn.innerHTML = '<i class="bi bi-moon-fill"></i>';
        localStorage.setItem('theme', 'light');
        document.dispatchEvent(new CustomEvent('theme:changed', { detail: { theme: 'light' } }));
    }
});
