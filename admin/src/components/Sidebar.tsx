import { NavLink } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';

const links = [
  { to: '/users', label: 'Users' },
  { to: '/servers', label: 'Servers' },
  { to: '/geoip', label: 'GeoIP Data' },
];

export default function Sidebar() {
  const { logout } = useAuth();

  return (
    <aside className="w-60 bg-slate-800 text-white flex flex-col">
      <div className="p-6 text-xl font-bold tracking-tight">VPN Dan Admin</div>
      <nav className="flex-1 px-3 space-y-1">
        {links.map((link) => (
          <NavLink
            key={link.to}
            to={link.to}
            className={({ isActive }) =>
              `block px-3 py-2 rounded-lg text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-slate-700 text-white'
                  : 'text-slate-300 hover:bg-slate-700 hover:text-white'
              }`
            }
          >
            {link.label}
          </NavLink>
        ))}
      </nav>
      <div className="p-4">
        <button
          onClick={logout}
          className="w-full px-3 py-2 text-sm text-slate-300 hover:text-white hover:bg-slate-700 rounded-lg transition-colors"
        >
          Logout
        </button>
      </div>
    </aside>
  );
}
