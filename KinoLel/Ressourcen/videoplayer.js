/**
 * This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/.
 *
 * KinoLel-App (iOS): Video-Player-Plugin für Jellyfin-Web. Videos laufen im nativen iOS-Player (AVPlayer) –
 * dadurch läuft der Ton weiter, wenn der Bildschirm gesperrt oder die App im Hintergrund ist.
 * Abgeleitet von jellyfin-ios (assets/js/plugins/NativeVideoPlayer.staticjs, MPL-2.0).
 */
(function () {
	class KinoLelVideoPlayer {
		constructor({ events, playbackManager, loading }) {
			this.name = 'KinoLel Video';
			this.type = 'mediaplayer';
			this.id = 'kinolelvideoplayer';
			this.priority = -1;
			this.isLocalPlayer = true;

			this.uri = null;
			this._isPlaying = false;
			this.positionMillis = 0;
			this.durationMillis = null;

			this.events = events;
			this.playbackManager = playbackManager;
			this.loading = loading;

			// Die App meldet den Zustand hierher (window.KinoLelVideo._reportStatus)
			window.KinoLelVideo = this;
		}

		destroy() {
			this.streamInfo = null;
			this.item = null;
			this.mediaSource = null;
			this.uri = null;
			this._isPlaying = false;
			this.positionMillis = 0;
		}

		// Zustand aus der App an Jellyfin-Web melden (Fortschritt, Pause, Ende)
		_reportStatus(status) {
			if (status.uri !== this.uri) {
				this.uri = status.uri;
				if (this.uri === null) {
					if (status.didPlayerCloseManually) {
						this.playbackManager.stop(this);
					}
					this._ereignis('stopped');
				} else if (this.streamInfo) {
					this.streamInfo.started = true;
				}
			}
			if (this.uri === null) return;

			if (typeof status.durationMillis === 'number') this.durationMillis = status.durationMillis;
			if (status.isPlaying !== this._isPlaying) {
				this._isPlaying = status.isPlaying;
				this._ereignis(this._isPlaying ? 'playing' : 'pause');
			}
			if (status.positionMillis !== this.positionMillis) {
				this.positionMillis = status.positionMillis;
				this._ereignis('timeupdate');
			}
		}

		_ereignis(name) {
			try {
				this.events.trigger(this, name);
			} catch (ex) {
				console.error(ex.name + '\n' + ex.message);
			}
		}

		canPlayMediaType(mediaType) {
			return mediaType === 'Video';
		}

		canPlayItem() {
			return true;
		}

		currentItem() { return this.item; }
		currentMediaSource() { return this.mediaSource; }

		currentTime(ms) {
			if (ms != null) {
				this.seek(ms);
				return;
			}
			return this.positionMillis;
		}

		duration() { return this.durationMillis; }
		isMuted() { return false; }
		isPlaying() { return this._isPlaying; }
		paused() { return !this._isPlaying; }
		volume() { return 100; }
		setVolume() { }
		setMute() { }

		play(streamInfo) {
			this.streamInfo = streamInfo;
			this.item = streamInfo.item;
			this.mediaSource = streamInfo.mediaSource;
			const item = streamInfo.item || {};
			let untertitel = item.SeriesName || '';
			if (item.SeriesName && item.ParentIndexNumber != null && item.IndexNumber != null) {
				untertitel += ' · S' + item.ParentIndexNumber + ' E' + item.IndexNumber;
			}
			// Fokus von der angetippten Kachel nehmen (wie Android 0.1.3): sonst spielt die Weboberfläche bei „Fortsetzen“
			// vom Server (Befehl „play“) die fokussierte Kachel ein zweites Mal ab.
			try {
				if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
			} catch (e) { /* egal */ }
			window.postKinoLel('video.play', {
				url: streamInfo.url,
				// Heruntergeladen? Dann spielt die App die lokale Datei (Downloads.swift)
				itemId: item.Id || null,
				playerStartPositionTicks: streamInfo.playerStartPositionTicks || 0,
				title: item.Name || '',
				subtitle: untertitel,
				backdropUrl: streamInfo.backdropUrl || null
			});
			// Wann der Player sichtbar ist, weiß die Web-Seite nicht -> Ladeanzeige kurz danach ausblenden
			return new Promise(resolve => window.setTimeout(resolve, 1500));
		}

		playPause() { window.postKinoLel('video.playPause'); }
		pause() { window.postKinoLel('video.pause'); }
		unpause() { window.postKinoLel('video.unpause'); }
		seek(ms) { window.postKinoLel('video.seek', ms); }

		stop(destroy) {
			window.postKinoLel('video.stop', !!destroy);
			return Promise.resolve();
		}

		getDeviceProfile() {
			return Promise.resolve(window.KinoLelVideoProfil || {});
		}
	}

	window.KinoLelVideoPlayer = () => KinoLelVideoPlayer;
})();
