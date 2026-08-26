# Local setup

Choose one option. You can use your own computer or a Codespace.

## Option 1: Run on your computer

You need a GitHub account and these tools:

* Git
* Bash, `curl`, `jq`, and `date`
* JDK 21
* [GitHub CLI](https://cli.github.com/) (`gh`)
* [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (`az`)
* [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) (`azd`)

Copy your workshop repository to your computer. Then start the application:

```bash
git clone https://github.com/<your-account>/<repository>.git
cd <repository>
./mvnw test
./mvnw spring-boot:run
```

Open <http://localhost:8080> in your browser. Press `Ctrl+C` to stop the
application.

## Option 2: Run in a Codespace

1. Open your workshop repository on GitHub.
2. Select **Code**, **Codespaces**, and **Create codespace on main**.
3. Wait for the Codespace to open.
4. Run these commands in its terminal:

```bash
./mvnw test
./mvnw spring-boot:run
```

When you see port `8080`, select **Open in Browser**. Press `Ctrl+C` to stop the
application.

## Prove partner review access

The Workshop Host gives you a partner before the workshop. Give your partner
access to your private workshop repository:

```bash
gh api --method PUT repos/<driver>/<repository>/collaborators/<partner> -f permission=push
```

Change `<driver>` to your GitHub name. Change `<repository>` to your repository
name. Change `<partner>` to your partner's GitHub name. Your partner must accept
the invitation.

1. Create an issue named `Preflight partner access proof`.
2. Ask your partner to add a test comment.
3. Check that you can see the comment.
4. Ask your partner to delete the comment, then close the issue.

If this test fails, fix the access before the workshop.

## Next step

Continue with [Azure Preflight and Cleanup](azure-preflight-and-cleanup.md).