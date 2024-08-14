;; Freelance Payment Platform Contract

;; Define error constants for better clarity
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))
(define-constant ERR-ALREADY-COMPLETED (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))

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
    ;; Set the new job in the jobs map
    (map-set jobs
      { job-id: job-id }
      { client: tx-sender, 
        freelancer: freelancer, 
        amount: amount, 
        completed: false }
    )
    ;; Increment the job counter
    (var-set job-counter job-id)
    (ok job-id)
  )
)

;; Complete a job and transfer payment
(define-public (complete-job (job-id uint))
  (let
    (
      (job (unwrap! (map-get? jobs { job-id: job-id }) 
        (err "Job not found")))
      (client (get client job))
      (freelancer (get freelancer job))
      (amount (get amount job))
      (fee (/ (* amount (var-get platform-fee)) u100))
      (freelancer-payment (- amount fee))
    )
    ;; Check if the caller is the client
    (asserts! (is-eq tx-sender client) 
      (err "Only the client can complete the job"))

    ;; Check if the job is not already completed
    (asserts! (not (get completed job)) 
      (err "Job already completed"))

    ;; Transfer the full amount from client to contract
    (unwrap! (stx-transfer? amount tx-sender (as-contract tx-sender))
      (err "Failed to transfer funds from client"))

    ;; Transfer payment to freelancer
    (unwrap! (as-contract (stx-transfer? freelancer-payment tx-sender freelancer))
      (err "Failed to transfer payment to freelancer"))

    ;; Transfer fee to contract owner
    (unwrap! (as-contract (stx-transfer? fee tx-sender (contract-caller)))
      (err "Failed to transfer fee to platform"))

    ;; Mark the job as completed
    (map-set jobs
      { job-id: job-id }
      (merge job { completed: true })
    )
    (ok true)
  )
)

;; Get job details
(define-read-only (get-job (job-id uint))
  (match (map-get? jobs { job-id: job-id })
    job job
    ERR-NOT-FOUND)
)

;; Update platform fee (only contract owner)
(define-public (update-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (contract-caller)) 
      (err "Only contract owner can update the fee"))
    (var-set platform-fee new-fee)
    (ok true)
  )
)

;; Get current platform fee
(define-read-only (get-platform-fee)
  (ok (var-get platform-fee))
)
