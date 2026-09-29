# Troubleshooting — github-workflows

**Version**: 1.0.0  
**Last Updated**: 26. März 2026

---

## Common Issues

### Workflow not triggered

**Symptom**: Push to main doesn't trigger workflow

**Causes & Solutions**:

1. **Branch protection**: Check if required checks are blocking
2. **Path filters**: Verify `paths` filter matches changed files
3. **Workflow disabled**: Check Actions tab → Enable workflow

```yaml
# Check your trigger configuration
on:
  push:
    branches: [main]
    paths:
      - 'src/**'  # Only triggers for src/ changes
```

---

### OIDC Authentication fails

**Symptom**: `Error: Not authorized to perform sts:AssumeRoleWithWebIdentity`

**Causes & Solutions**:

1. **Trust policy**: Verify IAM role trust policy includes GitHub OIDC
   ```json
   {
     "Effect": "Allow",
     "Principal": {
       "Federated": "arn:aws:iam::ACCOUNT:oidc-provider/token.actions.githubusercontent.com"
     },
     "Action": "sts:AssumeRoleWithWebIdentity",
     "Condition": {
       "StringEquals": {
         "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
       },
       "StringLike": {
         "token.actions.githubusercontent.com:sub": "repo:ORG/REPO:*"
       }
     }
   }
   ```

2. **Permissions**: Add `id-token: write` to workflow
   ```yaml
   permissions:
     id-token: write
   ```

3. **Role ARN**: Verify `AWS_ROLE_ARN` secret is correct

---

### ECR Push fails

**Symptom**: `denied: Your authorization token has expired`

**Solution**: Login to ECR before push

```yaml
- uses: aws-actions/amazon-ecr-login@v2
- run: docker push $ECR_URI
```

---

### Release-it creates no release

**Symptom**: Workflow runs but no version created

**Causes & Solutions**:

1. **No conventional commits**: Use `feat:`, `fix:`, etc.
   ```bash
   # Bad
   git commit -m "added feature"
   
   # Good
   git commit -m "feat: add new feature"
   ```

2. **Not on main branch**: release-it requires `main`
   ```json
   "git": { "requireBranch": "main" }
   ```

3. **No changes since last tag**: 
   ```bash
   git log $(git describe --tags --abbrev=0)..HEAD --oneline
   ```

---

### Create Release retries, or fails after 3 attempts (daily-business-US-063)

**Symptom**: The `Create Release` job's log shows `── release-it attempt 2/3 ──` (or 3/3), or ends
in `::error::release-it could not push after 3 attempts`.

**Cause**: an *ordinary* merge of a different PR landed on `main` while this run's own release-it
was still computing its version bump — a real, unavoidable race in any repo with more than one
active contributor, and one that gets more common, not less, the more merges land close together
(Nx IT's own merges included). Merging a PR is a plain git operation on GitHub, never gated by any
workflow's `concurrency:` group (that only serializes two runs of *this* workflow against each
other, which already works correctly and is a separate thing — see
`reusable-service-deployment.yml`'s own top-of-file comment).

**This is expected, self-healing behavior, not a bug to work around**: the step re-fetches `main`'s
current tip and retries, up to 3 times, and on success releases whatever is on `main` by then —
including the commit that raced it. No developer action needed for a retry that eventually
succeeds; nothing to look for beyond the log line itself.

**If it still fails after 3 attempts** (three-plus merges landing inside the same short window —
rare, but the whole reason this note exists): the merge was **not released or deployed**. Re-run
the workflow once `main` has settled, or push a new commit to retrigger. The hourly deployment-
drift check (`reusable-deployment-drift-check.yml`) remains the outer safety net if this is somehow
still missed — it compares what `main` claims is released against what's actually running.

---

### CodeDeploy deployment fails

**Symptom**: `Deployment already in progress`

**Solution**: Wait or cancel existing deployment

```bash
# List active deployments
aws deploy list-deployments \
  --application-name APP_NAME \
  --deployment-group-name DG_NAME \
  --include-only-statuses InProgress

# Cancel deployment
aws deploy stop-deployment --deployment-id DEPLOYMENT_ID
```

---

### Task Definition not found

**Symptom**: `An error occurred: task definition not found`

**Solution**: Verify task family exists

```bash
aws ecs list-task-definitions --family-prefix FAMILY_NAME
```

---

### Docker build fails

**Symptom**: `failed to solve: failed to compute cache key`

**Causes & Solutions**:

1. **Missing Dockerfile**: Check path `.docker/Dockerfile`
2. **Missing context files**: Ensure all files exist
3. **Cache issues**: Try without cache
   ```yaml
   - run: docker compose build --no-cache
   ```

---

### Tests fail in CI but pass locally

**Symptom**: Tests pass on local machine but fail in GitHub Actions

**Causes & Solutions**:

1. **Missing secrets**: CI uses dummy secrets
   ```yaml
   - run: |
       mkdir -p secrets
       echo "dummy" > secrets/database_password.txt
   ```

2. **Service startup timing**: Add health checks
   ```yaml
   - run: |
       docker compose up -d
       sleep 10  # Wait for services
   ```

3. **Environment differences**: Check Node/Docker versions

---

## Debug Tools

### Enable Debug Logging

Add repository secret:
```
ACTIONS_STEP_DEBUG=true
ACTIONS_RUNNER_DEBUG=true
```

### View Full Logs

```yaml
- name: Debug
  run: |
    echo "GitHub Context:"
    echo '${{ toJSON(github) }}'
    
    echo "Inputs:"
    echo '${{ toJSON(inputs) }}'
```

### Check AWS Configuration

```yaml
- name: Debug AWS
  run: |
    aws sts get-caller-identity
    aws iam list-attached-role-policies --role-name ROLE_NAME
```

### Inspect Docker

```yaml
- name: Debug Docker
  run: |
    docker images
    docker ps -a
    docker compose logs
```

---

## Error Messages Reference

| Error | Cause | Solution |
|-------|-------|----------|
| `workflow_call is not a recognized event` | Invalid workflow syntax | Check YAML indentation |
| `Required input 'X' not provided` | Missing input | Add required input to caller |
| `Resource not accessible by integration` | Missing permissions | Add `permissions:` block |
| `Process completed with exit code 1` | Step failed | Check step logs |
| `Error: HttpError: Not Found` | Wrong repository/path | Verify repository and ref |

---

## Getting Help

1. **Check workflow logs**: Expand failed step
2. **Enable debug mode**: Add `ACTIONS_STEP_DEBUG` secret
3. **Review examples**: Check `examples/` directory
4. **Open issue**: Provide workflow logs + error message

---

## Further Documentation

[Quick Start](00-quick-start.md) | [Development](07-development.md) | [Architecture](02-architecture.md)
