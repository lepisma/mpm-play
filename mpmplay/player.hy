;; Player

(import [mpm.mpm [Mpm]])
(import [mpm.db :as db])
(import [mpmplay.cache [Ytcache]])
(import [sanic [Sanic]])
(import mplayer)
(import [sanic.response [json :as sanic-json]])
(require [high.macros [*]])

(defn get-beets-file-url [beets-db beets-id]
  (let [res (beets-db.query (+ "SELECT path FROM items WHERE id = " (str beets-id)))
        file-url (get (first res) "path")]
    (+ "file://" (if (is (type file-url) bytes)
                   (.decode file-url "utf8")
                   file-url))))

(defn get-beets-db [config-db]
  "Return connection to beets db from config-db"
  (let [sources (get config-db "sources")]
    (db.get-dataset-conn (get (sources.find-one :resolver "beets") "url"))))

(defn get-song-identifier [song]
  (let [title (get song "title")
        artist (get song "artist")]
    (if title (+ title " - " artist)
        (get song "url"))))

(defmacro/g! route [r-path func-body]
  "Setup route mapping"
  `(with-decorator (self.app.route ~r-path)
     (defn ~g!route-func [req] ~func-body)))

(defclass Player []
  (defn --init-- [self config]
    (setv self.mpm-instance (Mpm config))
    (setv self.database self.mpm-instance.database)
    (setv self.config (get config "player"))
    (setv self.port (get self.config "port"))
    (setv self.yt-cache (Ytcache #p(get self.config "cache")))
    (setv self.beets-db (get-beets-db self.database))
    (setv self.playlist [])
    (setv self.current -1)
    (setv self.repeat False)
    (setv self.random False)
    (setv self.mplayer-instance (mplayer.Player)))

  (defn parse-mpm-url [self song]
    "Parse song in a playable url"
    (let [url (get song "url")
          [source-type id] (.split url ":")]
      (cond [(= source-type "yt") (self.yt-cache.get-playable-url song)]
            [(= source-type "beets") (get-beets-file-url self.beets-db (int id))]
            [True (rase (NotImplementedError))])))

  (defn clear-playlist [self]
    (setv self.playlist [])
    (setv self.current -1))

  (defn add-songs [self song-ids]
    (+= self.playlist song-ids))

  (defn toggle-playback [self]
    (self.mplayer-instance.pause))

  (defn play-current [self]
    "Play the current song"
    (let [current-id (nth self.playlist self.current)
          song (db.get-song self.database current-id)
          murl (self.parse-mpm-url song)]
      (print (+ "Playing: " (get-song-identifier song)))
      (self.mplayer-instance.loadfile murl)
      (if self.mplayer-instance.paused
        (self.mplayer-instance.pause))))

  (defn get-current-song [self]
    "Return current song info"
    (let [song-id (nth self.playlist self.current)]
      (db.get-song self.database song-id)))

  (defn prev-song [self]
    "Go back to prev song"
    (if (= self.current 0)
      (setv self.current (- (len self.playlist) 1))
      (-- self.current))
    (self.play-current))

  (defn next-song [self]
    "Next song"
    (if (= self.current (- (len self.playlist) 1))
      (setv self.current 0)
      (++ self.current))
    (self.play-current))

  (defn start-server [self]
    "Start music server"
    (setv self.app (Sanic))

    (route "/"
           (sanic-json "Hello World"))

    (route "/current"
           (if (>= self.current 0)
             (sanic-json (self.get-current-song))
             (sanic-json "NA")))

    (route "/next"
           (if (!= (len self.playlist) 0)
             (do
              (self.next-song)
              (sanic-json "ok"))
             (sanic-json "NA")))

    (route "/prev"
           (if (!= (len self.playlist) 0)
             (do
              (self.prev-song)
              (sanic-json "ok"))
             (sanic-json "NA")))

    (route "/clear"
           (do
            (self.clear-playlist)
            (sanic-json "ok")))

    (route "/add"
           (let [song-ids (list (map int (.split (get req.raw_args "ids") ",")))]
             (self.add-songs song-ids)
             (sanic-json "ok")))

    (route "/toggle"
           (do
            (self.toggle-playback)
            (sanic-json "ok")))

    (self.app.run :host "127.0.0.1" :port self.port)))
