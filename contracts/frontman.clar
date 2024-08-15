;; Freelance Payment Platform Smart Contract

;; =============== Constants ===============

(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-INVALID-STATE (err u102))
(define-constant ERR-INVALID-INPUT (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))

(define-constant JOB-STATE-OPEN u1)
(define-constant JOB-STATE-IN-PROGRESS u2)
(define-constant JOB-STATE-COMPLETED u3)
(define-constant JOB-STATE-DISPUTED u4)

(define-constant MINIMUM-JOB-AMOUNT u1000)  ;; in microstacks
(define-constant MAXIMUM-PLATFORM-FEE u100) ;; 100%
(define-constant ESCROW-PERCENTAGE u50)     ;; 50%

;; =============== Data Variables ===============

(define-data-var platform-fee uint u5)      ;; 5% platform fee
(define-data-var job-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;; =============== Data Maps ===============

(define-map jobs 
  { job-id: uint }
  { 
    client: principal, 
    freelancer: principal, 
    total-amount: uint, 
    state: uint,
    category: (string-ascii 20),
    escrow-amount: uint
  }
)

(define-map user-jobs { user: principal } (list 10 uint))

(define-map user-ratings
  { user: principal }
  { total-rating: uint, rating-count: uint }
)

(define-map disputes
  { dispute-id: uint }
  { 
    job-id: uint,
    raised-by: principal,
    description: (string-utf8 500),
    resolved: bool
  }
)

;; =============== Private Functions ===============

(define-private (is-contract-owner)
  (is-eq tx-sender (var-get contract-owner))
)

(define-private (calculate-escrow-amount (total-amount uint))
  (/ (* total-amount ESCROW-PERCENTAGE) u100)
)

(define-private (calculate-platform-fee (amount uint))
  (/ (* amount (var-get platform-fee)) u100)
)

(define-private (add-job-to-user (user principal) (job-id uint))
  (let ((current-jobs (default-to (list) (map-get? user-jobs { user: user }))))
    (map-set user-jobs { user: user } (unwrap! (as-max-len? (concat current-jobs job-id) u10) ERR-INVALID-INPUT))
  )
)

(define-private (transfer-funds (sender principal) (recipient principal) (amount uint))
  (match (stx-transfer? amount sender recipient)
    success (ok true)
    error ERR-TRANSFER-FAILED
  )
)

;; =============== Public Functions ===============

(define-public (create-job (freelancer principal) (total-amount uint) (category (string-ascii 20)))
  (let
    (
      (job-id (+ (var-get job-counter) u1))
      (escrow-amount (calculate-escrow-amount total-amount))
    )
    (asserts! (>= total-amount MINIMUM-JOB-AMOUNT) ERR-INVALID-INPUT)
    (try! (transfer-funds tx-sender (as-contract tx-sender) escrow-amount))
    (map-set jobs
      { job-id: job-id }
      { 
        client: tx-sender, 
        freelancer: freelancer, 
        total-amount: total-amount, 
        state: JOB-STATE-OPEN,
        category: category,
        escrow-amount: escrow-amount
      }
    )
    (var-set job-counter job-id)
    (add-job-to-user tx-sender job-id)
    (add-job-to-user freelancer job-id)
    (ok job-id)
  )
)

(define-public (start-job (job-id uint))
  (let
    (
      (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get freelancer job)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job) JOB-STATE-OPEN) ERR-INVALID-STATE)
    (map-set jobs
      { job-id: job-id }
      (merge job { state: JOB-STATE-IN-PROGRESS })
    )
    (ok true)
  )
)

(define-public (complete-job (job-id uint))
  (let
    (
      (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-NOT-FOUND))
      (total-amount (get total-amount job))
      (platform-fee (calculate-platform-fee total-amount))
      (freelancer-payment (- total-amount platform-fee))
    )
    (asserts! (is-eq tx-sender (get client job)) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job) JOB-STATE-IN-PROGRESS) ERR-INVALID-STATE)
    
    (try! (transfer-funds tx-sender (as-contract tx-sender) (- total-amount (get escrow-amount job))))
    (try! (as-contract (transfer-funds tx-sender (get freelancer job) freelancer-payment)))
    (try! (as-contract (transfer-funds tx-sender (var-get contract-owner) platform-fee)))
    
    (map-set jobs
      { job-id: job-id }
      (merge job { state: JOB-STATE-COMPLETED })
    )
    (ok true)
  )
)

(define-public (raise-dispute (job-id uint) (description (string-utf8 500)))
  (let
    (
      (job (unwrap! (map-get? jobs { job-id: job-id }) ERR-NOT-FOUND))
      (dispute-id (+ (var-get dispute-counter) u1))
    )
    (asserts! (or (is-eq tx-sender (get client job)) (is-eq tx-sender (get freelancer job))) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get state job) JOB-STATE-IN-PROGRESS) ERR-INVALID-STATE)
    
    (map-set disputes
      { dispute-id: dispute-id }
      {
        job-id: job-id,
        raised-by: tx-sender,
        description: description,
        resolved: false
      }
    )
    (var-set dispute-counter dispute-id)
    (map-set jobs
      { job-id: job-id }
      (merge job { state: JOB-STATE-DISPUTED })
    )
    (ok dispute-id)
  )
)

(define-public (resolve-dispute (dispute-id uint) (winner principal))
  (let
    (
      (dispute (unwrap! (map-get? disputes { dispute-id: dispute-id }) ERR-NOT-FOUND))
      (job (unwrap! (map-get? jobs { job-id: (get job-id dispute) }) ERR-NOT-FOUND))
    )
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (not (get resolved dispute)) ERR-INVALID-STATE)
    
    (try! (as-contract (transfer-funds tx-sender winner (get total-amount job))))
    
    (map-set disputes
      { dispute-id: dispute-id }
      (merge dispute { resolved: true })
    )
    (map-set jobs
      { job-id: (get job-id dispute) }
      (merge job { state: JOB-STATE-COMPLETED })
    )
    (ok true)
  )
)

(define-public (rate-user (user principal) (rating uint))
  (let
    (
      (current-rating (default-to { total-rating: u0, rating-count: u0 } 
        (map-get? user-ratings { user: user })))
    )
    (asserts! (and (>= rating u1) (<= rating u5)) ERR-INVALID-INPUT)
    (map-set user-ratings
      { user: user }
      { 
        total-rating: (+ (get total-rating current-rating) rating),
        rating-count: (+ (get rating-count current-rating) u1)
      }
    )
    (ok true)
  )
)

(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (asserts! (<= new-fee MAXIMUM-PLATFORM-FEE) ERR-INVALID-INPUT)
    (var-set platform-fee new-fee)
    (ok true)
  )
)

(define-public (update-contract-owner (new-owner principal))
  (begin
    (asserts! (is-contract-owner) ERR-UNAUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)

;; =============== Read-Only Functions ===============

(define-read-only (get-job (job-id uint))
  (map-get? jobs { job-id: job-id })
)

(define-read-only (get-user-jobs (user principal))
  (map-get? user-jobs { user: user })
)

(define-read-only (get-user-rating (user principal))
  (match (map-get? user-ratings { user: user })
    rating (ok (/ (get total-rating rating) (get rating-count rating)))
    (ok u0))
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-platform-fee)
  (ok (var-get platform-fee))
)