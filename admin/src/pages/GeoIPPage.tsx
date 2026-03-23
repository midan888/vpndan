import { useState, useEffect } from 'react';
import { api } from '../api/client';
import type { GeoIPCountry } from '../types';

const regionNames = new Intl.DisplayNames(['en'], { type: 'region' });

function countryFlag(code: string): string {
  const base = 0x1f1e6 - 65; // 'A' = 65
  return [...code.toUpperCase()]
    .map((c) => String.fromCodePoint(base + c.charCodeAt(0)))
    .join('');
}

function CountryRow({ country }: { country: GeoIPCountry }) {
  const [expanded, setExpanded] = useState(false);
  const [cidrs, setCidrs] = useState<string[]>([]);
  const [loading, setLoading] = useState(false);

  const handleToggle = async () => {
    if (!expanded && cidrs.length === 0) {
      setLoading(true);
      try {
        const data = await api.getCountryCIDRs(country.country);
        setCidrs(data.cidrs ?? []);
      } catch {
        setCidrs([]);
      } finally {
        setLoading(false);
      }
    }
    setExpanded(!expanded);
  };

  let displayName: string;
  try {
    displayName = regionNames.of(country.country) ?? country.country;
  } catch {
    displayName = country.country;
  }

  return (
    <>
      <tr
        className="hover:bg-gray-50 cursor-pointer"
        onClick={handleToggle}
      >
        <td className="px-6 py-4">
          <span className="mr-2 text-lg">{countryFlag(country.country)}</span>
          {displayName}
        </td>
        <td className="px-6 py-4 font-mono text-gray-600">{country.country}</td>
        <td className="px-6 py-4 text-gray-600">{country.count.toLocaleString()}</td>
        <td className="px-6 py-4 text-gray-400">
          <svg
            className={`w-4 h-4 transition-transform ${expanded ? 'rotate-90' : ''}`}
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
          </svg>
        </td>
      </tr>
      {expanded && (
        <tr>
          <td colSpan={4} className="px-6 py-4 bg-gray-50">
            {loading ? (
              <span className="text-gray-400">Loading CIDRs...</span>
            ) : cidrs.length === 0 ? (
              <span className="text-gray-400">No CIDR data</span>
            ) : (
              <div className="max-h-64 overflow-y-auto">
                <div className="flex flex-wrap gap-1.5">
                  {cidrs.map((cidr) => (
                    <span
                      key={cidr}
                      className="inline-block px-2 py-0.5 bg-white border border-gray-200 rounded text-xs font-mono text-gray-700"
                    >
                      {cidr}
                    </span>
                  ))}
                </div>
                <div className="mt-3 text-xs text-gray-400">
                  {cidrs.length.toLocaleString()} CIDR range{cidrs.length !== 1 ? 's' : ''}
                </div>
              </div>
            )}
          </td>
        </tr>
      )}
    </>
  );
}

export default function GeoIPPage() {
  const [countries, setCountries] = useState<GeoIPCountry[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [search, setSearch] = useState('');

  useEffect(() => {
    (async () => {
      try {
        const data = await api.listGeoIPCountries();
        setCountries(data ?? []);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to load GeoIP data');
      } finally {
        setLoading(false);
      }
    })();
  }, []);

  const totalRanges = countries.reduce((sum, c) => sum + c.count, 0);

  const filtered = search
    ? countries.filter((c) => {
        const q = search.toLowerCase();
        let name: string;
        try {
          name = regionNames.of(c.country)?.toLowerCase() ?? '';
        } catch {
          name = '';
        }
        return c.country.toLowerCase().includes(q) || name.includes(q);
      })
    : countries;

  if (loading) return <div className="text-gray-500">Loading GeoIP data...</div>;
  if (error) return <div className="text-red-600">{error}</div>;

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h1 className="text-2xl font-bold text-gray-900">
          GeoIP Data{' '}
          <span className="text-gray-400 font-normal text-lg">
            ({countries.length} countries, {totalRanges.toLocaleString()} ranges)
          </span>
        </h1>
      </div>

      <div className="mb-4">
        <input
          type="text"
          placeholder="Search countries..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full max-w-sm px-4 py-2 text-sm border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent"
        />
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-gray-50 border-b border-gray-200">
            <tr>
              <th className="px-6 py-3 font-medium text-gray-500">Country</th>
              <th className="px-6 py-3 font-medium text-gray-500">Code</th>
              <th className="px-6 py-3 font-medium text-gray-500">CIDR Ranges</th>
              <th className="px-6 py-3 font-medium text-gray-500 w-10"></th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-100">
            {filtered.map((country) => (
              <CountryRow key={country.country} country={country} />
            ))}
          </tbody>
        </table>
        {filtered.length === 0 && (
          <div className="text-center text-gray-400 py-12">
            {search ? 'No countries match your search' : 'No GeoIP data loaded. Run the seed-geoip command.'}
          </div>
        )}
      </div>
    </div>
  );
}
