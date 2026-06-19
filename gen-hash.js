const bcrypt = require('bcrypt');
bcrypt.hash('Test1234!', 10).then(h => console.log(h));
