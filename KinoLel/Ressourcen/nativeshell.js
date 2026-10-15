/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * KinoLel-App (iOS): Brücke zwischen der Jellyfin-Weboberfläche von kinolel.de und der App.
 * Abgeleitet von jellyfin-ios (assets/js/NativeShell.staticjs, MPL-2.0).
 * Fester Server: kein "multiserver" -> Jellyfin-Web zeigt direkt die Anmeldung, keine Serverauswahl.
 */
(function () {
	if (window.NativeShell) return;

	function postKinoLel(event, data) {
		try {
			window.webkit.messageHandlers.kinolel.postMessage({ event: event, data: data === undefined ? null : data });
		} catch (e) { /* außerhalb der App */ }
	}
	window.postKinoLel = postKinoLel;

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

		downloadFile: function (item) { postKinoLel('openUrl', { url: item && item.url }); },
		enableFullscreen: function () { /* Vollbild übernimmt der native Player */ },
		disableFullscreen: function () { },
		getPlugins: function () { return ['KinoLelVideoPlayer']; },
		openUrl: function (url, target) { postKinoLel('openUrl', { url: url, target: target }); },
		updateMediaSession: function () { },
		hideMediaSession: function () { }
	};
})();
