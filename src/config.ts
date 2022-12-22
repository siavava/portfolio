

const email = 'amittaijoel@outlook.com';

const social = [
    {
      heading: 'GitHub',
      _path: 'https://github.com/siavava',
    },
    {
      heading: 'Instagram',
      _path: 'https://www.instagram.com/siavava',
    },
    {
      heading: 'Twitter',
      _path: 'https://twitter.com/siavava',
    },
    {
      heading: 'Linkedin',
      _path: 'https://www.linkedin.com/in/siavava',
    },
  ];

const homeLinks = [
    {
      heading: 'About',
      _path: '/#about',
    },
    {
      heading: 'Experience',
      _path: '/#jobs',
    },
    {
      heading: 'Work',
      _path: '/#projects',
    },
    {
      heading: 'Contact',
      _path: '/#contact',
    },
  ];

const otherLinks = [
    {
      heading: 'Blog',
      _path: '/blog',
      show: true,
    },
    {
      heading: 'Resume',
      _path: '/resume',
      show: true,
    },
    {
      heading: 'Art Portfolio',
      _path: '/portfolio',
      show: true,
    },
  ].filter((link) => link.show);

const navLinks = { homeLinks, otherLinks };

const colors = {
    green: '#64ffda',
    navy: '#0a192f',
    darkNavy: '#020c1b',
  };

const srConfig = (delay = 200, viewFactor = 0.25) => ({
    origin: 'bottom',
    distance: '20px',
    duration: 500,
    delay,
    rotate: { x: 0, y: 0, z: 0 },
    opacity: 0,
    scale: 1,
    easing: 'cubic-bezier(0.645, 0.045, 0.355, 1)',
    mobile: true,
    reset: false,
    useDelay: 'always',
    viewFactor,
    viewOffset: { top: 0, right: 0, bottom: 0, left: 0 },
  });

export { email, social, navLinks, colors, srConfig };
