/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * KinoLel-App (iOS): Brücke zwischen der Jellyfin-Weboberfläche von kinolel.de und der App.
 * Abgeleitet von jellyfin-ios (assets/js/NativeShell.staticjs, MPL-2.0).
 * Fester Server: kein "multiserver" -> Jellyfin-Web zeigt direkt die Anmeldung, keine Serverauswahl.
 * Downloads (wie die Android-App): "filedownload"/"downloadmanagement" -> App (kinolelDownloads.js, Downloads.swift).
 */
(function () {
	if (window.NativeShell) return;

	function postKinoLel(event, data) {
		try {
			window.webkit.messageHandlers.kinolel.postMessage({ event: event, data: data === undefined ? null : data });
		} catch (e) { /* außerhalb der App */ }
	}
	window.postKinoLel = postKinoLel;

	// Anfragen mit Antwort an die App (Promise), z. B. Download-Zustand
	var frageKanal = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.kinolelFrage;
	window.KinoLelNative = {
		frage: function (event, data) {
			if (!frageKanal) return Promise.reject(new Error('außerhalb der App'));
			return frageKanal.postMessage({ event: event, data: data === undefined ? null : data });
		}
	};

	// Download-Wünsche kurz sammeln: Jellyfin-Web ruft downloadFile für jede Folge einzeln auf -> eine Auswahl für alle
	var wartend = [];
	var sammelZeit = null;
	function herunterladen(ids) {
		ids.forEach(function (id) { if (id && wartend.indexOf(id) < 0) wartend.push(id); });
		clearTimeout(sammelZeit);
		sammelZeit = setTimeout(function () {
			var liste = wartend;
			wartend = [];
			if (window.KinoLelDownloads) window.KinoLelDownloads.anfragen(liste);
		}, 300);
	}
	function idVon(eintrag) {
		return eintrag && (eintrag.itemId || (eintrag.item && eintrag.item.Id) || eintrag.Id);
	}

	// Nachrichten vom Server (Dashboard „Nachricht senden“, KinoLel-Streams-Grenze) auch über dem nativen Player zeigen:
	// Live-Verbindung der Weboberfläche mithören (Befehle wie Pause/Stopp erreichen den Player über den playbackManager).
	(function () {
		var Original = window.WebSocket;
		if (!Original) return;
		function MitHoeren(url, protokolle) {
			var ws = protokolle === undefined ? new Original(url) : new Original(url, protokolle);
			try {
				if (/\/socket/i.test(String(url))) {
					ws.addEventListener('message', function (e) {
						try {
							var m = JSON.parse(e.data);
							if (m && m.MessageType === 'GeneralCommand' && m.Data && m.Data.Name === 'DisplayMessage') {
								var a = m.Data.Arguments || {};
								postKinoLel('nachricht', { kopf: a.Header || '', text: a.Text || '', dauer: Number(a.TimeoutMs) || 0 });
							}
						} catch (x) { /* keine JSON-Nachricht */ }
					});
				}
			} catch (x) { /* egal */ }
			return ws;
		}
		MitHoeren.prototype = Original.prototype;
		['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'].forEach(function (k) { MitHoeren[k] = Original[k]; });
		window.WebSocket = MitHoeren;
	})();

	var info = window.KinoLelAppInfo || {};

	// Unterstützte Funktionen (wie Safari auf iOS, ohne Mehr-Server, ohne Beenden)
	var FEATURES = [
		'plugins',
		'externallinks',
		'externallinkdisplay',
		'fullscreenchange',
		'physicalvolumecontrol',
		'remotecontrol',
		'remotevideo',
		'displaylanguage',
		'displaymode',
		'downloadmanagement',
		'filedownload',
		'subtitleappearancesettings',
		'subtitleburnsettings',
		'fileinput'
	];

	['error', 'warn'].forEach(function (stufe) {
		var original = console[stufe];
		console[stufe] = function () {
			try { postKinoLel('console.' + stufe, Array.prototype.map.call(arguments, String).join(' ')); } catch (e) { /* egal */ }
			return original.apply(console, arguments);
		};
	});

	window.NativeShell = {
		AppHost: {
			init: function () { return Promise.resolve(info); },
			appName: function () { return info.appName; },
			appVersion: function () { return info.appVersion; },
			deviceId: function () { return info.deviceId; },
			deviceName: function () { return info.deviceName; },
			exit: function () { /* iOS: Apps beenden sich nicht selbst */ },
			getDefaultLayout: function () { return 'mobile'; },
			getDeviceProfile: function (profileBuilder) {
				// Profil für den Web-Player (z. B. Musik); Videos laufen im nativen Player (videoplayer.js)
				return profileBuilder({
					audioChannels: 6,
					enableMkvProgressive: false,
					disableHlsVideoAudioCodecs: ['opus']
				});
			},
			supports: function (command) {
				return !!command && FEATURES.indexOf(command.toLowerCase()) !== -1;
			}
		},

		downloadFile: function (item) { herunterladen([idVon(item)]); },
		downloadFiles: function (items) { herunterladen((items || []).map(idVon)); },
		openDownloadManager: function () { postKinoLel('downloads.oeffnen'); },
		enableFullscreen: function () { /* Vollbild übernimmt der native Player */ },
		disableFullscreen: function () { },
		getPlugins: function () { return ['KinoLelVideoPlayer']; },
		openUrl: function (url, target) { postKinoLel('openUrl', { url: url, target: target }); },
		updateMediaSession: function () { },
		hideMediaSession: function () { }
	};
})();
