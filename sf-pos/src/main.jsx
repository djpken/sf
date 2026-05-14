import React from 'react';
import { createRoot } from 'react-dom/client';
import './styles.css';
import './pos-data.js';
import './pos-ui.jsx';
import './ipad-pos.jsx';

createRoot(document.getElementById('root')).render(<window.IPadPosApp />);
