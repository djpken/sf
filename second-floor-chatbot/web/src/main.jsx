import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';
import Admin from './Admin.jsx';
import './styles.css';

// 沒有 router;依路徑分流。Vite 預設 spa fallback,/admin 會載入 index.html。
const isAdmin = window.location.pathname.replace(/\/+$/, '').endsWith('/admin');

createRoot(document.getElementById('root')).render(
  <StrictMode>
    {isAdmin ? <Admin /> : <App />}
  </StrictMode>,
);
