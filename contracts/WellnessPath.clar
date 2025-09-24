;; WellnessPath - Holistic wellness journey tracking and milestone recognition platform
;; Version: 1.0.0

(define-data-var wellness-facilitator principal tx-sender)
(define-data-var total-wellness-progress uint u0)
(define-data-var vitality-reward-rate uint u25) ;; vitality points per progress unit
(define-data-var last-vitality-celebration uint u0)

(define-map participant-progress principal uint)
(define-map participant-pathways principal (string-utf8 64))
(define-map pathway-certifications (string-utf8 64) bool)

;; Error codes
(define-constant err-unauthorized-facilitator (err u1200))
(define-constant err-facilitator-already-exists (err u1201))
(define-constant err-invalid-progress-amount (err u1202))
(define-constant err-no-celebration-ready (err u1203))
(define-constant err-no-progress-recorded (err u1204))
(define-constant err-invalid-pathway (err u1205))
(define-constant err-pathway-not-certified (err u1206))

;; Verify facilitator authorization
(define-private (is-wellness-facilitator (caller principal))
  (begin
    (asserts! (is-eq caller (var-get wellness-facilitator)) err-unauthorized-facilitator)
    (ok true)))

;; Initialize wellness journey program
(define-public (launch-wellness-program (facilitator principal))
  (begin
    (asserts! (is-none (map-get? participant-progress facilitator)) err-facilitator-already-exists)
    (var-set wellness-facilitator facilitator)
    (ok "WellnessPath journey program launched successfully")))

;; Certify wellness pathway
(define-public (certify-pathway (pathway-name (string-utf8 64)))
  (begin
    (try! (is-wellness-facilitator tx-sender))
    (asserts! (> (len pathway-name) u0) err-invalid-pathway)
    (map-set pathway-certifications pathway-name true)
    (ok "Wellness pathway certified successfully")))

;; Record wellness progress
(define-public (record-wellness-progress (progress-units uint) (pathway (string-utf8 64)))
  (begin
    (asserts! (> progress-units u0) err-invalid-progress-amount)
    (asserts! (default-to false (map-get? pathway-certifications pathway)) err-pathway-not-certified)

    (let ((current-progress (default-to u0 (map-get? participant-progress tx-sender))))
      (map-set participant-progress tx-sender (+ current-progress progress-units))
      (map-set participant-pathways tx-sender pathway)
      (var-set total-wellness-progress (+ (var-get total-wellness-progress) progress-units))
      (ok (+ current-progress progress-units)))))

;; Calculate vitality celebrations
(define-public (calculate-vitality-celebrations)
  (begin
    (try! (is-wellness-facilitator tx-sender))
    (let ((current-celebration (+ (var-get last-vitality-celebration) u1))
          (total-progress (var-get total-wellness-progress)))
      (asserts! (> total-progress (var-get last-vitality-celebration)) err-no-celebration-ready)

      (let ((new-vitality-points (* (var-get vitality-reward-rate) total-progress)))
        (var-set last-vitality-celebration current-celebration)
        (ok new-vitality-points)))))

;; Claim wellness milestone rewards
(define-public (claim-wellness-rewards)
  (begin
    (let ((participant-progress-amount (default-to u0 (map-get? participant-progress tx-sender))))
      (asserts! (> participant-progress-amount u0) err-no-progress-recorded)

      (let ((total-progress (var-get total-wellness-progress))
            (vitality-points (* (var-get vitality-reward-rate) participant-progress-amount))
            (progress-percentage (/ (* participant-progress-amount u100000) total-progress)))

        (let ((final-rewards (/ (* progress-percentage vitality-points) u100000)))
          (map-delete participant-progress tx-sender)
          (map-delete participant-pathways tx-sender)
          (var-set total-wellness-progress (- (var-get total-wellness-progress) participant-progress-amount))
          (ok (+ participant-progress-amount final-rewards)))))))

;; Read-only functions
(define-read-only (get-wellness-progress (participant principal))
  (default-to u0 (map-get? participant-progress participant)))

(define-read-only (get-participant-pathway (participant principal))
  (map-get? participant-pathways participant))

(define-read-only (get-total-wellness-progress)
  (var-get total-wellness-progress))

(define-read-only (is-pathway-certified (pathway-name (string-utf8 64)))
  (default-to false (map-get? pathway-certifications pathway-name)))

(define-read-only (get-wellness-stats)
  {
    facilitator: (var-get wellness-facilitator),
    total-progress: (var-get total-wellness-progress),
    vitality-rate: (var-get vitality-reward-rate)
  })
