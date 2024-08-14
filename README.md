# Freelance Payment Platform Smart Contract

## Overview

This project implements a basic smart contract for a freelance payment platform using the Clarity language. The contract facilitates the creation of jobs, completion of jobs, and secure transfer of payments between clients and freelancers.

## Features

- Create new jobs with specified freelancer and payment amount
- Complete jobs and automatically transfer payments
- Platform fee mechanism
- Job details retrieval
- Updatable platform fee (restricted to contract owner)

## Contract Functions

### `create-job`

Creates a new job in the system.

Parameters:
- `freelancer`: Principal (address) of the freelancer
- `amount`: Payment amount for the job

Returns: Job ID

### `complete-job`

Marks a job as completed and transfers the payment.

Parameters:
- `job-id`: ID of the job to complete

Returns: Boolean indicating success

### `get-job`

Retrieves details of a specific job.

Parameters:
- `job-id`: ID of the job to retrieve

Returns: Job details (client, freelancer, amount, completion status)

### `update-platform-fee`

Updates the platform fee percentage (restricted to contract owner).

Parameters:
- `new-fee`: New fee percentage

Returns: Boolean indicating success

## Data Structures

- `jobs`: Map storing job details
- `job-counter`: Counter for generating unique job IDs
- `platform-fee`: Current platform fee percentage

## Security Considerations

- Only the client who created a job can mark it as completed
- Platform fee can only be updated by the contract owner
- Payments are securely transferred using the contract as an intermediary

## Getting Started

1. Deploy the contract to a Stacks blockchain network
2. Interact with the contract using a Stacks wallet or through API calls

## Development

To further develop or customize this contract:

1. Set up a Clarity development environment
2. Modify the contract as needed
3. Test thoroughly using Clarity testing frameworks
4. Deploy updates to the blockchain
