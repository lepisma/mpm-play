;; Player

(import [mpm.mpm [Mpm]])
(import [mpm.db :as db])
(import [mpmplay.cache [Ytcache]])
(import [mpmplay.hooks [run-hook]])
(import [sanic [Sanic]])
(import [mplayer [Player]])
(import [sanic.response [json :as sanic-json]])
(import [high.utils [*]])
(import [threading [Lock Thread]])
(import [time [sleep]])
(import os)
(require [high.macros [*]])

(defn get-beets-song [beets-db beets-id]
  (let [res (beets-db.query (+ "SELECT title, artist, album, path from items WHERE id = " (str beets-id)))]
    (first res)))

(defn get-beets-file-url [beets-db beets-id]
  (let [song (get-beets-song beets-db beets-id)
        file-url (get song "path")
        decoded-url (if (is (type file-url) bytes)
                        (.decode file-url "utf8")
                        file-url)]
    (if (os.path.exists decoded-url)
        (+ "file://" decoded-url)
        (raise FileNotFoundError))))

(defn get-beets-db [config-db]
  "Return connection to beets db from config-db"
  (let [sources (get config-db "sources")]
    (db.get-dataset-conn (get (sources.find-one :resolver "beets") "url"))))

(defn get-song-identifier [song]
  (let [title (get song "title")
        artist (get song "artist")]
    (if title (+ title " - " artist)
        (get song "url"))))

(defmacro/g! route [r-path &rest func-body]
  "Setup route mapping"
  `(with-decorator (self.app.route ~r-path :methods ["POST" "GET"])
     (defn ~g!route-func [req] (with [self.lock]
                                 (do ~@func-body)))))

(defclass Server []
  (defn --init-- [self config]
    (setv mpm-instance (Mpm config))
    (setv self.database mpm-instance.database)
    (setv self.config (get config "player"))
    (setv self.port (get self.config "port"))
    (setv self.yt-cache (Ytcache #p(get self.config "cache")))
    (setv self.beets-db (get-beets-db self.database))
    (setv self.playlist [])
    (setv self.current -1)
    (setv self.lock (Lock))
    (setv self.sleep None)
    (setv self.repeat False)
    (setv self.played False)
    (setv self.should-play False) ; Internal flag to check in loop
    (setv self.mplayer-instance (Player :args ["-cache" 10000 "-novideo"]))
    (setv self.loop (Thread :target self.p-loop))
    (self.loop.start))

  (defn get-state [self]
    "Return current state of the player. Following states are possible
- done    : done with playing a song
- started : just started, no files loaded
- paused  : song is loaded and paused
- playing : song is loaded and is getting played"
    (if (is self.mplayer-instance.percent-pos None)
        (if self.mplayer-instance.paused "done" "started")
        (if self.mplayer-instance.paused "paused" "playing")))

  (defn p-loop [self]
    (while True
      (sleep 0.5)
      (with [self.lock]
        (let [state (self.get-state)]
          (if self.should-play
              (cond [(= state "paused") (self.play)]
                    [(= state "done") (self.next-song)]
                    [(= state "playing") (self.mark-played)]))))))

  (defn parse-mpm-url [self song]
    "Parse song in a playable url"
    (let [url (get song "url")
          [source-type id] (.split url ":")]
      (cond [(= source-type "yt") (self.yt-cache.get-playable-url song)]
            [(= source-type "beets") (try
                                       (get-beets-file-url self.beets-db (int id))
                                       (except [FileNotFoundError]
                                         (do (print "Local file not found, using youtube fallback")
                                             (self.yt-cache.get-playable-url song))))]
            [True (raise (NotImplementedError))])))

  (defn clear-playlist [self]
    (setv self.playlist [])
    (setv self.current -1))

  (defn add-songs [self song-ids]
    (print (+ "Adding " (str (len song-ids)) " songs"))
    (+= self.playlist song-ids))

  (defn play [self]
    (if (= (self.get-state) "paused") (self.mplayer-instance.pause))
    (setv self.should-play True))

  (defn pause [self]
    (if (= (self.get-state) "playing") (self.mplayer-instance.pause))
    (setv self.should-play False))

  (defn toggle [self]
    (if (not self.should-play) (self.play) (self.pause)))

  (defn toggle-repeat [self]
    (setv self.repeat (not self.repeat)))

  (defn seek [self seconds]
    (if self.should-play (self.mplayer-instance.seek seconds)))

  (defn mark-played [self]
    "Mark the current song as played"
    (if (not self.played)
        (let [total-time self.mplayer-instance.length
              current-time self.mplayer-instance.time-pos]
          (if (> current-time (min (* 4 60) (/ total-time 2)))
              (do (run-hook "song-played" self.config)
                  (setv self.played True)
                  (if self.sleep (-- self.sleep)))))))

  (defn get-current-song [self]
    "Return current song info"
    (db.get-song self.database (nth self.playlist self.current)))

  (defn play-current [self]
    "Play the current song"
    (setv self.played False)
    (let [song (self.get-current-song)
          murl (self.parse-mpm-url song)]
      (print (+ "Playing: " (get-song-identifier song)))
      (self.mplayer-instance.loadfile murl)
      (setv self.should-play True)
      (run-hook "song-changed" self.config)))

  (defn prev-song [self]
    "Go back to prev song"
    (cond [self.repeat]
          [(= self.current 0) (setv self.current (- (len self.playlist) 1))]
          [True (-- self.current)])
    (self.play-current))

  (defn next-song [self]
    "Next song"
    (if (or (is self.sleep None) (>= self.sleep 0))
        (do (cond [self.repeat]
                  [(= self.current (- (len self.playlist) 1)) (setv self.current 0)]
                  [True (++ self.current)])
            (self.play-current))))

  (defn start [self]
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
               (do (self.next-song)
                   (sanic-json "ok"))
               (sanic-json "NA")))

    (route "/prev"
           (if (!= (len self.playlist) 0)
               (do (self.prev-song)
                   (sanic-json "ok"))
               (sanic-json "NA")))

    (route "/seek"
           (let [value (int (get req.raw-args "value"))]
             (self.seek value)
             (sanic-json "ok")))

    (route "/sleep"
           (let [value (int (get req.raw-args "value"))]
             (setv self.sleep (if (> value 0) value None))
             (sanic-json "ok")))

    (route "/clear"
           (self.clear-playlist)
           (sanic-json "ok"))

    (route "/add"
           (let [id-str (first (get req.form "ids"))
                 ids (emap int (.split id-str ","))]
             (self.add-songs ids)
             (sanic-json "ok")))

    (route "/toggle"
           (self.toggle)
           (sanic-json "ok"))

    (route "/repeat"
           (self.toggle-repeat)
           (sanic-json self.repeat))

    (route "/state"
           (sanic-json {"repeat" self.repeat
                        "sleep" self.sleep
                        "list-length" (len self.playlist)
                        "current" self.current
                        "played" self.played}))

    (self.app.run :host "127.0.0.1" :port self.port)))
