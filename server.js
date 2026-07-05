const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const os = require('os');

const app = express();
const port = 9091;
const comicsDir = 'E:\\Comics';

app.use(cors());

if (!fs.existsSync(comicsDir)) {
    try {
        fs.mkdirSync(comicsDir, { recursive: true });
    } catch (e) {
        console.error(e);
    }
}

app.use('/files', express.static(comicsDir));

function getLocalIp() {
    const interfaces = os.networkInterfaces();
    for (const name of Object.keys(interfaces)) {
        for (const iface of interfaces[name]) {
            if (iface.family === 'IPv4' && !iface.internal) {
                return iface.address;
            }
        }
    }
    return '127.0.0.1';
}

function findComicFile(dirPath) {
    try {
        const files = fs.readdirSync(dirPath);
        return files.find(f => 
            f.toLowerCase().endsWith('.cbr') || 
            f.toLowerCase().endsWith('.cbz') || 
            f.toLowerCase().endsWith('.zip') || 
            f.toLowerCase().endsWith('.pdf')
        );
    } catch (e) {
        return null;
    }
}

app.get('/comics', (req, res) => {
    try {
        if (!fs.existsSync(comicsDir)) {
            return res.status(404).json({ error: 'Root directory not found' });
        }

        const localIp = getLocalIp();
        const baseUrl = `http://${localIp}:${port}/files`;
        let comicList = [];
        let idCounter = 1;

        const categories = fs.readdirSync(comicsDir);

        categories.forEach(categoryName => {
            const categoryPath = path.join(comicsDir, categoryName);
            if (!fs.statSync(categoryPath).isDirectory()) return;

            const items = fs.readdirSync(categoryPath);

            const directComicFile = findComicFile(categoryPath);
            if (directComicFile) {
                const cover = items.find(f => f.toLowerCase() === 'cover.jpg' || f.toLowerCase() === 'cover.png');
                comicList.push({
                    id: idCounter++,
                    title: categoryName,
                    category: 'Uncategorized',
                    coverUrl: cover ? `${baseUrl}/${encodeURIComponent(categoryName)}/${cover}` : '',
                    downloadUrl: `${baseUrl}/${encodeURIComponent(categoryName)}/${encodeURIComponent(directComicFile)}`
                });
            }

            items.forEach(seriesName => {
                const seriesPath = path.join(categoryPath, seriesName);
                if (!fs.statSync(seriesPath).isDirectory()) return;

                const seriesFiles = fs.readdirSync(seriesPath);
                const comicFile = findComicFile(seriesPath);

                if (comicFile) {
                    const cover = seriesFiles.find(f => f.toLowerCase() === 'cover.jpg' || f.toLowerCase() === 'cover.png');
                    comicList.push({
                        id: idCounter++,
                        title: seriesName,
                        category: categoryName,
                        coverUrl: cover ? `${baseUrl}/${encodeURIComponent(categoryName)}/${encodeURIComponent(seriesName)}/${cover}` : '',
                        downloadUrl: `${baseUrl}/${encodeURIComponent(categoryName)}/${encodeURIComponent(seriesName)}/${encodeURIComponent(comicFile)}`
                    });
                }
            });
        });

        res.json(comicList);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

const server = app.listen(port, '0.0.0.0', (err) => {
    if (err) {
        console.error(err);
        return;
    }
    console.log(`Comic server running at http://${getLocalIp()}:${port}`);
});

server.on('error', (err) => {
    console.error(err);
});

process.on('uncaughtException', (err) => {
    console.error(err);
});

process.on('unhandledRejection', (reason) => {
    console.error(reason);
});
