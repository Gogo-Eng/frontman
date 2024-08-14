
;; frontman
;; A platform where freelancers and client can engage

;; Freelance Payment Platform Contract

;; Define data variables
(define-data-var platform-fee uint u5) ;; 5% platform fee
(define-map jobs 
  { job-id: uint }
  { client: principal, freelancer: principal, amount: uint, completed: bool }
)
(define-data-var job-counter uint u0)

;; Create a new job
(define-public (create-job (freelancer principal) (amount uint))
  (let
    (
      (job-id (+ (var-get job-counter) u1))
    )
    (map-set jobs
      { job-id: job-id }
      { client: tx-sender, 
        freelancer: freelancer, 
        amount: amount, 
        completed: false }
    )
    (var-set job-counter job-id)
    (ok job-id)
  )
)

;; Complete a job and transfer payment
(define-public (complete-job (job-id uint))
  (let
    (
      (job (unwrap! (map-get? jobs { job-id: job-id }) (err u1)))
      (client (get client job))
      (freelancer (get freelancer job))
      (amount (get amount job))
      (fee (/ (* amount (var-get platform-fee)) u100))
      (freelancer-payment (- amount fee))
    )
    (asserts! (is-eq tx-sender client) (err u2))
    (asserts! (not (get completed job)) (err u3))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (try! (as-contract (stx-transfer? freelancer-payment tx-sender freelancer)))
    (try! (as-contract (stx-transfer? fee tx-sender (contract-caller))))
    (map-set jobs
      { job-id: job-id }
      (merge job { completed: true })
    )
    (ok true)
  )
)

;; Get job details
(define-read-only (get-job (job-id uint))
  (map-get? jobs { job-id: job-id })
)

;; Update platform fee (only contract owner)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (contract-caller)) (err u4))
    (var-set platform-fee new-fee)
    (ok true)
  )
)
