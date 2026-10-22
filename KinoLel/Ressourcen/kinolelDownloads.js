/**
 * KinoLel-App (iOS) – Downloads wie bei Netflix (Lel 20.10.2026: „… downloaden und dann direkt in der App anschauen.
 * Auch wenn kein Internet vorhanden ist.“). Gleiche Oberfläche wie in der Android-App (kinolelDownloads.js):
 * sichtbarer Knopf „Herunterladen“ auf Film-, Folgen-, Staffel- und Serienseiten mit Zustand und Fortschritt, kleine
 * Knöpfe an den Folgen. Herunterladen, Liste und Abspielen übernimmt die App (Downloads.swift) über KinoLelNative.
 * Folgt dem Jellyfin-Recht „Herunterladen erlauben“ (Lel 20.10.: Recht für alle).
 */
(function () {
	'use strict';
	if (window.__kinolelDownloads) return;
	window.__kinolelDownloads = true;
	const N = window.KinoLelNative;
	if (!N) return;

	const TEXTE = {
		de: {
			laden: 'Herunterladen', staffel: 'Staffel herunterladen', serie: 'Alle Folgen herunterladen',
			fertig: 'Heruntergeladen – in „Downloads“ ansehen', laedt: 'Wird heruntergeladen', wartet: 'Wartet auf den Download (WLAN?)',
			fehler: 'Download fehlgeschlagen – erneut versuchen', teil: '%1 von %2 Folgen heruntergeladen'
		},
		hu: {
			laden: 'Letöltés', staffel: 'Évad letöltése', serie: 'Összes epizód letöltése',
			fertig: 'Letöltve – megnézhető a „Letöltések” között', laedt: 'Letöltés folyamatban', wartet: 'Letöltésre vár (Wi-Fi?)',
			fehler: 'A letöltés nem sikerült – újra', teil: '%2 epizódból %1 letöltve'
		},
		en: {
			laden: 'Download', staffel: 'Download season', serie: 'Download all episodes',
			fertig: 'Downloaded – watch in “Downloads”', laedt: 'Downloading', wartet: 'Waiting to download (Wi-Fi?)',
			fehler: 'Download failed – try again', teil: '%1 of %2 episodes downloaded'
		}
	};
	const VIDEO = ['Movie', 'Episode', 'Video', 'MusicVideo'];
	const SAMMLUNG = ['Season', 'Series'];
	const ORDNER = ['Series', 'Season', 'BoxSet', 'Folder', 'CollectionFolder', 'Playlist'];
	const SYMBOL = { fertig: 'download_done', laedt: 'downloading', wartet: 'schedule', fehler: 'error_outline' };

	function t() {
		const l = (document.documentElement.lang || navigator.language || 'de').slice(0, 2).toLowerCase();
		return TEXTE[l] || TEXTE.de;
	}

	const norm = (id) => String(id || '').replace(/-/g, '').toLowerCase();
	let recht = null;
	const titel = new Map();

	function api() {
		const a = window.ApiClient;
		return a && a.accessToken && a.accessToken() && a.getCurrentUserId() ? a : null;
	}

	// Anmeldung an die App geben (Downloads und Nachmelden der Offline-Position laufen auch ohne Weboberfläche)
	let letzteAnmeldung = '';
	function anmeldung() {
		const a = api();
		if (!a) return null;
		return { token: a.accessToken(), userId: a.getCurrentUserId(), deviceId: a.deviceId() };
	}
	function anmeldungMelden() {
		const daten = anmeldung();
		const text = daten ? JSON.stringify(daten) : '';
		if (!daten || text === letzteAnmeldung) return;
		letzteAnmeldung = text;
		N.frage('anmeldung', daten).catch(() => { letzteAnmeldung = ''; });
	}

	function aktuelleId() {
		if (!/^#\/details/.test(location.hash)) return null;
		const m = location.hash.match(/[?&]id=([0-9a-f-]{32,36})/i);
		return m ? norm(m[1]) : null;
	}

	async function holeTitel(id) {
		if (titel.has(id)) return titel.get(id);
		const a = api();
		if (!a) return null;
		const versprechen = a.getItem(a.getCurrentUserId(), id).catch(() => null);
		titel.set(id, versprechen);
		return versprechen;
	}

	async function hatRecht() {
		if (recht === null) {
			try {
				const u = await api().getCurrentUser();
				recht = !!(u && u.Policy && u.Policy.EnableContentDownloading);
			} catch (e) { return false; }
		}
		return recht;
	}

	async function status(ids) {
		try { return (await N.frage('dl.status', ids)) || {}; } catch (e) { return {}; }
	}

	// --- Titel für die App aufbereiten (Staffeln/Serien → Folgen) ---

	function bildPfad(x) {
		if (x.ImageTags && x.ImageTags.Primary) return '/Items/' + x.Id + '/Images/Primary?maxHeight=360&quality=85&tag=' + x.ImageTags.Primary;
		if (x.SeriesId && x.SeriesPrimaryImageTag) return '/Items/' + x.SeriesId + '/Images/Primary?maxHeight=360&quality=85&tag=' + x.SeriesPrimaryImageTag;
		return null;
	}

	function kompakt(x) {
		const q = (x.MediaSources || [])[0] || null;
		const stroeme = (q && q.MediaStreams) || x.MediaStreams || [];
		const video = stroeme.find((s) => s.Type === 'Video') || {};
		const zahl = (v) => (typeof v === 'number' ? v : null);
		return {
			id: norm(x.Id), name: x.Name || '', typ: x.Type || '', serie: x.SeriesName || null,
			staffel: zahl(x.ParentIndexNumber), folge: zahl(x.IndexNumber),
			dauer: x.RunTimeTicks || (q && q.RunTimeTicks) || 0,
			position: (x.UserData && x.UserData.PlaybackPositionTicks) || 0,
			gesehen: !!(x.UserData && x.UserData.Played),
			bild: bildPfad(x),
			quelle: q && q.Id ? {
				id: q.Id, container: q.Container || '', groesse: q.Size || 0,
				video: { codec: video.Codec || '', tag: video.CodecTag || '', profil: video.Profile || '', breite: video.Width || 0, hoehe: video.Height || 0 },
				audio: stroeme.filter((s) => s.Type === 'Audio').map((s) => ({ index: s.Index, codec: s.Codec || '', sprache: s.Language || '', standard: !!s.IsDefault })),
				untertitel: stroeme.filter((s) => s.Type === 'Subtitle' && s.IsTextSubtitleStream)
					.map((s) => ({ index: s.Index, codec: s.Codec || '', sprache: s.Language || '', standard: !!s.IsDefault })),
				standardAudio: zahl(q.DefaultAudioStreamIndex),
				standardUntertitel: zahl(q.DefaultSubtitleStreamIndex)
			} : null
		};
	}

	async function aufloesen(ids) {
		const a = api();
		const uid = a.getCurrentUserId();
		const liste = [];
		for (const id of ids) {
			const it = await a.getItem(uid, id);
			if (it.IsFolder || ORDNER.includes(it.Type)) {
				const r = await a.getItems(uid, {
					ParentId: id, Recursive: true, IncludeItemTypes: 'Movie,Episode,Video,MusicVideo', Fields: 'MediaSources,CanDownload',
					SortBy: 'ParentIndexNumber,IndexNumber,SortName', SortOrder: 'Ascending', IsMissing: false, EnableTotalRecordCount: false
				});
				(r.Items || []).forEach((x) => { if (x.LocationType !== 'Virtual') liste.push(x); });
			} else {
				liste.push(it);
			}
		}
		return liste.filter((x) => x.CanDownload !== false).map(kompakt);
	}

	// Download-Wunsch (Knopf hier oder „…“-Menü über NativeShell.downloadFile): App zeigt die Qualitätswahl
	async function anfragen(ids) {
		ids = (ids || []).filter(Boolean);
		if (!ids.length) return;
		let daten;
		try {
			daten = { titel: await aufloesen(ids), anmeldung: anmeldung() };
		} catch (e) {
			console.warn('KinoLel-Downloads:', e);
			daten = { titel: [], fehler: true };
		}
		N.frage('dl.anfragen', daten).catch(() => {});
	}
	window.KinoLelDownloads = { anfragen: anfragen };

	// --- Knöpfe ---

	function symbol(element, name) {
		const s = element.querySelector('.kl-dl-symbol');
		if (s && s.textContent !== name) s.textContent = name;
	}

	function neuerKnopf(klasse) {
		const b = document.createElement('button');
		b.type = 'button';
		b.setAttribute('is', 'emby-button');
		b.className = klasse;
		b.innerHTML = '<div class="detailButton-content"><span class="material-icons detailButton-icon kl-dl-symbol" aria-hidden="true">download</span>' +
			'<span class="kl-dl-prozent"></span></div>';
		return b;
	}

	function darstellen(b, st, text) {
		const zustand = st ? st.s : null;
		symbol(b, SYMBOL[zustand] || 'download');
		const p = b.querySelector('.kl-dl-prozent');
		const prozent = zustand === 'laedt' && st.p >= 0 ? st.p + ' %' : '';
		if (p.textContent !== prozent) p.textContent = prozent;
		const titelText = zustand ? (t()[zustand] || text) : text;
		if (b.title !== titelText) { b.title = titelText; b.setAttribute('aria-label', titelText); }
		b.dataset.zustand = zustand || '';
	}

	function stil() {
		if (document.getElementById('kl-dl-stil')) return;
		const s = document.createElement('style');
		s.id = 'kl-dl-stil';
		s.textContent =
			'.kl-dl .detailButton-content{display:flex;flex-direction:column;align-items:center}' +
			'.kl-dl .kl-dl-prozent{font-size:.7em;line-height:1;margin-top:2px}.kl-dl .kl-dl-prozent:empty{display:none}' +
			'.kl-dl[data-zustand="fertig"] .kl-dl-symbol,.kl-dl-mini[data-zustand="fertig"] .kl-dl-symbol{color:#9aa4ff}' +
			'.kl-dl-mini{background:none;border:0;color:inherit;padding:.3em;margin:0 .2em;cursor:pointer;flex-shrink:0;display:inline-flex;align-items:center}' +
			'.kl-dl-mini .detailButton-content{display:flex;align-items:center;gap:.2em}.kl-dl-mini .kl-dl-prozent{font-size:.75em}' +
			'.kl-dl-mini .kl-dl-prozent:empty{display:none}';
		document.head.appendChild(s);
	}

	function oeffnen() { postKinoLel('downloads.oeffnen'); }

	// Kleine Knöpfe an den Folgen einer Staffel/Serie
	async function folgenKnoepfe(seite) {
		const zeilen = Array.from(seite.querySelectorAll('.listItem[data-id][data-type="Episode"], .listItem[data-id][data-isfolder="false"]'))
			.filter((z) => !z.closest('.kl-dl-mini'));
		if (!zeilen.length) return [];
		const ids = zeilen.map((z) => norm(z.getAttribute('data-id')));
		const st = await status(ids);
		zeilen.forEach((zeile, i) => {
			const id = ids[i];
			let b = zeile.querySelector(':scope .kl-dl-mini');
			if (!b) {
				b = neuerKnopf('kl-dl-mini');
				b.dataset.id = id;
				b.addEventListener('click', (ev) => {
					ev.preventDefault();
					ev.stopPropagation();
					const z = b.dataset.zustand;
					if (z === 'fertig' || z === 'laedt' || z === 'wartet') oeffnen();
					else anfragen([id]);
				}, true);
				const ziel = zeile.querySelector('.listViewUserDataButtons') || zeile;
				ziel.insertBefore(b, ziel.firstChild);
			}
			darstellen(b, st[id], t().laden);
		});
		return ids.map((id) => st[id]);
	}

	let laeuft = false;
	async function aktualisieren() {
		if (laeuft) return;
		laeuft = true;
		try {
			anmeldungMelden();
			const id = aktuelleId();
			const seite = document.querySelector('.itemDetailPage:not(.hide)');
			if (!id || !seite || !api()) return;
			const leiste = seite.querySelector('.mainDetailButtons');
			if (!leiste) return;
			const it = await holeTitel(id);
			const vorhanden = leiste.querySelector('.kl-dl');
			const istVideo = it && VIDEO.includes(it.Type);
			const istSammlung = it && SAMMLUNG.includes(it.Type);
			let darf = istVideo || istSammlung;
			if (darf) darf = istVideo ? !!it.CanDownload : await hatRecht();
			if (!darf) {
				if (vorhanden) vorhanden.remove();
				return;
			}
			stil();
			let b = vorhanden;
			if (!b || b.dataset.id !== id) {
				if (b) b.remove();
				b = neuerKnopf('button-flat detailButton kl-dl');
				b.dataset.id = id;
				b.addEventListener('click', () => {
					const z = b.dataset.zustand;
					if (z === 'fertig' || (istVideo && (z === 'laedt' || z === 'wartet'))) oeffnen();
					else anfragen([id]);
				});
				const play = Array.from(leiste.querySelectorAll('.btnPlay, .btnReplay, .btnResume')).pop();
				leiste.insertBefore(b, play ? play.nextSibling : leiste.firstChild);
			}
			if (istVideo) {
				darstellen(b, (await status([id]))[id], t().laden);
			} else {
				const folgen = await folgenKnoepfe(seite);
				const fertig = folgen.filter((s) => s && s.s === 'fertig').length;
				const laedt = folgen.find((s) => s && (s.s === 'laedt' || s.s === 'wartet'));
				const text = it.Type === 'Season' ? t().staffel : t().serie;
				darstellen(b, laedt ? { s: laedt.s, p: laedt.p } : (folgen.length && fertig === folgen.length ? { s: 'fertig', p: 100 } : null), text);
				if (fertig && fertig < folgen.length && !laedt) {
					const hinweis = t().teil.replace('%1', fertig).replace('%2', folgen.length);
					b.title = text + ' (' + hinweis + ')';
				}
			}
		} catch (e) {
			console.warn('KinoLel-Downloads:', e);
		} finally {
			laeuft = false;
		}
	}

	setInterval(aktualisieren, 1500);
	window.addEventListener('hashchange', () => setTimeout(aktualisieren, 300));
})();
