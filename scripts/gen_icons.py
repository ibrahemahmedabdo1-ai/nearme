#!/usr/bin/env python3
"""Generates the NEAR ME 3D icon set (SVG, 96x96). Output: mobile/packages/near_me_core/assets/icons + design/icons."""
import pathlib, shutil
G = {  # glyph paths on a 24x24 grid (stroke style), rendered white with an emboss shadow
'home':'<path d="M3 10.5 12 3l9 7.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/>',
'near':'<circle cx="12" cy="12" r="3"/><circle cx="12" cy="12" r="8"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3"/>',
'chat':'<path d="M21 12a8 8 0 0 1-11.6 7.1L4 20l1-4.6A8 8 0 1 1 21 12z"/>',
'user':'<circle cx="12" cy="8" r="4"/><path d="M4 21c1-4 4-6 8-6s7 2 8 6"/>',
'heart':'<path d="M12 21s-8-5.3-8-11a4.5 4.5 0 0 1 8-2.8A4.5 4.5 0 0 1 20 10c0 5.7-8 11-8 11z"/>',
'star':'<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z"/>',
'bell':'<path d="M6 8a6 6 0 1 1 12 0c0 7 3 8 3 8H3s3-1 3-8"/><path d="M10 21h4"/>',
'shield':'<path d="M12 3 4 6v6c0 5 3.5 8 8 9 4.5-1 8-4 8-9V6z"/><path d="m9 12 2 2 4-4"/>',
'filter':'<path d="M3 5h18M6 12h12M10 19h4"/>',
'close':'<path d="M6 6l12 12M18 6 6 18"/>',
'chart':'<path d="M4 20V10M10 20V4M16 20v-8M22 20H2"/>',
'users':'<circle cx="9" cy="8" r="3.5"/><path d="M2 20c.8-3.5 3.5-5 7-5s6.2 1.5 7 5"/><path d="M16 4.5a3.5 3.5 0 0 1 0 7M18 15c2 .5 3.5 2 4 5"/>',
'ticket':'<path d="M3 8a2 2 0 0 0 0 8v2a1 1 0 0 0 1 1h16a1 1 0 0 0 1-1v-2a2 2 0 0 1 0-8V6a1 1 0 0 0-1-1H4a1 1 0 0 0-1 1z"/><path d="M14 5v14"/>',
'sliders':'<path d="M4 6h10M18 6h2M4 12h2M10 12h10M4 18h12"/><circle cx="16" cy="6" r="2"/><circle cx="8" cy="12" r="2"/><circle cx="18" cy="18" r="2"/>',
'send':'<path d="m22 2-9 20-3-8-8-3z"/>',
'pin':'<path d="M12 21s7-6 7-12a7 7 0 0 0-14 0c0 6 7 12 7 12z"/><circle cx="12" cy="9" r="2.5"/>',
'palette':'<path d="M12 3a9 9 0 1 0 0 18c1.5 0 2-1 1.5-2s0-2 1.5-2h2a3 3 0 0 0 3-3c0-5-4-11-8-11z"/><circle cx="8" cy="11" r="1"/><circle cx="12" cy="7.5" r="1"/><circle cx="16" cy="11" r="1"/>',
}
C = {  # (light, base, dark) gradient stops
'home':('#B79CFF','#8B5CF6','#5B35D6'),'near':('#FF8AC0','#FF4D94','#D6246D'),'chat':('#7DD3FC','#38BDF8','#1D7FD6'),'user':('#C4B5FD','#8B5CF6','#5B35D6'),
'heart':('#FFA0BE','#FF4D6D','#D11F45'),'star':('#FFE27A','#FBBF24','#E08A06'),'bell':('#FFD580','#FB923C','#D9600F'),'shield':('#7EF0C0','#34D399','#0F9F6E'),
'filter':('#7DD3FC','#38BDF8','#1D7FD6'),'close':('#9AA3B8','#64748B','#3B4559'),'chart':('#B79CFF','#8B5CF6','#5B35D6'),'users':('#FF8AC0','#EC4899','#BE185D'),
'ticket':('#FFD580','#F59E0B','#C77700'),'sliders':('#7EF0C0','#14B8A6','#0B7F72'),'send':('#B79CFF','#8B5CF6','#5B35D6'),'pin':('#FF9A9A','#F43F5E','#C0173C'),'palette':('#FFA0BE','#FF4D94','#8B5CF6')}
def svg(name):
    l, b, d = C[name]; g = G[name]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 96 96" width="96" height="96">
<defs>
<linearGradient id="b" x1="0.15" y1="0" x2="0.85" y2="1"><stop offset="0" stop-color="{l}"/><stop offset=".55" stop-color="{b}"/><stop offset="1" stop-color="{d}"/></linearGradient>
<linearGradient id="gl" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".62"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
<linearGradient id="rim" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".7"/><stop offset=".5" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="{d}" stop-opacity=".9"/></linearGradient>
<filter id="sh" x="-30%" y="-30%" width="160%" height="170%"><feDropShadow dx="0" dy="6" stdDeviation="5" flood-color="{d}" flood-opacity=".55"/></filter>
<filter id="gs" x="-20%" y="-20%" width="140%" height="150%"><feDropShadow dx="0" dy="1.6" stdDeviation="1.1" flood-color="#000" flood-opacity=".35"/></filter>
</defs>
<rect x="8" y="8" width="80" height="80" rx="26" fill="url(#b)" filter="url(#sh)"/>
<rect x="8.75" y="8.75" width="78.5" height="78.5" rx="25.3" fill="none" stroke="url(#rim)" stroke-width="1.5"/>
<path d="M14 30C14 18 22 11 34 11h28c12 0 20 7 20 19 0 6-12 12-34 12S14 36 14 30z" fill="url(#gl)"/>
<g transform="translate(48 49) scale(2.35) translate(-12 -12)" fill="none" stroke="#fff" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" filter="url(#gs)">{g}</g>
</svg>
'''
out = [pathlib.Path('mobile/packages/near_me_core/assets/icons'), pathlib.Path('design/icons')]
for o in out: o.mkdir(parents=True, exist_ok=True)
for n in G:
    for o in out: (o/f'{n}.svg').write_text(svg(n))
print(len(G), 'icons')
