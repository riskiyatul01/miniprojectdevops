const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
    res.json({
        message: "Hello from DevSecOps Pipeline!",
        status: "Running",
        environment: process.env.NODE_ENV || "development"
    });
});

// Endpoint untuk Healthcheck (Standard High Availability)
app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

app.listen(PORT, () => {
    console.log(`App is running on port ${PORT}`);
});
