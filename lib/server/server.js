const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const mysql = require('mysql2/promise');
const path = require('path');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 5001;
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-here';

// ======== Middleware ========
app.use(cors({ origin: '*', credentials: true }));
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ======== Multer Configuration for File Upload ========
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ 
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: function (req, file, cb) {
    const allowedTypes = /jpeg|jpg|png|gif/;
    const extname = allowedTypes.test(path.extname(file.originalname).toLowerCase());
    const mimetype = allowedTypes.test(file.mimetype);
    
    if (mimetype && extname) {
      return cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'));
    }
  }
});

const uploadsPath = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsPath)) {
  fs.mkdirSync(uploadsPath);
}

// ======== Koneksi MySQL ========
const pool = mysql.createPool({
  host: 'localhost',
  user: 'root',
  password: '', 
  database: 'property',
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0
});

// ======== JWT Middleware ========
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ success: false, error: 'Invalid or expired token' });
    }
    req.user = user;
    next();
  });
};

// ======== ROUTES ========

// --- Ping Test
app.get('/api/ping', (req, res) => {
  res.json({ success: true, message: 'Server aktif' });
});

// --- Get All Properties
app.get('/api/properties', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT * FROM property ORDER BY id_property DESC');
    const properties = rows.map(p => ({
      ...p,
      image: p.image?.startsWith('http')
        ? p.image
        : `${req.protocol}://${req.get('host')}/uploads/${p.image}`
    }));
    res.json({ success: true, data: properties });
  } catch (err) {
    console.error('Error fetching properties:', err.message);
    res.status(500).json({ success: false, message: 'Error fetching properties' });
  }
});

// --- Add New Property
// === Add New Property - FIXED VERSION ===
app.post('/api/properties', authenticateToken, upload.single('image'), async (req, res) => {
  try {
    console.log('=== ADD PROPERTY DEBUG ===');
    console.log('Request body:', req.body);
    console.log('Request file:', req.file ? req.file.filename : 'No file');
    console.log('User from token:', req.user);

    // Extract data from request
    const { title, type, price, ethPrice, address, description } = req.body;
    
    // Validation - Check required fields
    const required = ['title', 'price', 'ethPrice', 'address', 'description'];
    const missing = required.filter(field => !req.body[field] || req.body[field].toString().trim() === '');

    if (missing.length > 0) {
      console.log('Missing fields:', missing);
      return res.status(400).json({ 
        success: false, 
        message: 'Field berikut wajib diisi: ' + missing.join(', '),
        missing: missing
      });
    }

    // Validate and parse numeric fields
    let parsedPrice, parsedEthPrice;
    
    try {
      // Parse price (remove any non-numeric characters except decimal point)
      const cleanPrice = price.toString().replace(/[^0-9.]/g, '');
      parsedPrice = parseFloat(cleanPrice);
      
      if (isNaN(parsedPrice) || parsedPrice <= 0) {
        throw new Error('Invalid price value');
      }
    } catch (err) {
      console.log('Price parsing error:', err);
      return res.status(400).json({ 
        success: false, 
        message: 'Harga harus berupa angka yang valid dan lebih besar dari 0'
      });
    }

    try {
      // Parse ETH price
      const cleanEthPrice = ethPrice.toString().replace(/[^0-9.]/g, '');
      parsedEthPrice = parseFloat(cleanEthPrice);
      
      if (isNaN(parsedEthPrice) || parsedEthPrice <= 0) {
        throw new Error('Invalid ETH price value');
      }
    } catch (err) {
      console.log('ETH price parsing error:', err);
      return res.status(400).json({ 
        success: false, 
        message: 'Harga ETH harus berupa angka yang valid dan lebih besar dari 0'
      });
    }

    // Prepare property data for database
    const propertyData = {
      title: title.toString().trim(),
      type: type ? type.toString().trim() : 'house', // Default to 'house' if not provided
      price: parsedPrice,
      ethPrice: parsedEthPrice,
      image: req.file ? `http://localhost:5001/uploads/${req.file.filename}` : null,
      address: address.toString().trim(),
      description: description.toString().trim(),
    };

    console.log('Processed property data:', propertyData);

    // Insert into database
    const [result] = await pool.query('INSERT INTO property SET ?', propertyData);
    console.log('Database insert result:', result);

    // Prepare response data
    const newProperty = {
      id_property: result.insertId,
      ...propertyData,
      image: propertyData.image 
        ? `${req.protocol}://${req.get('host')}/uploads/${propertyData.image}`
        : null
    };

    console.log('Property successfully added with ID:', result.insertId);

    res.status(201).json({ 
      success: true, 
      message: 'Property berhasil ditambahkan', 
      data: newProperty 
    });

  } catch (err) {
    console.error('=== ADD PROPERTY ERROR ===');
    console.error('Error details:', err);
    console.error('Stack trace:', err.stack);
    
    // Handle specific database errors
    if (err.code === 'ER_NO_SUCH_TABLE') {
      return res.status(500).json({ 
        success: false, 
        message: 'Tabel property tidak ditemukan. Periksa struktur database.' 
      });
    } else if (err.code === 'ER_BAD_FIELD_ERROR') {
      return res.status(500).json({ 
        success: false, 
        message: 'Field database tidak sesuai. Periksa struktur tabel property.' 
      });
    } else if (err.code === 'ER_DUP_ENTRY') {
      return res.status(400).json({ 
        success: false, 
        message: 'Data property sudah ada.' 
      });
    }
    
    res.status(500).json({ 
      success: false, 
      message: 'Gagal menambahkan property', 
      error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error',
      details: process.env.NODE_ENV === 'development' ? err.stack : undefined
    });
  }
});
// --- Update Property
app.put('/api/properties/:id', authenticateToken, upload.single('image'), async (req, res) => {
  try {
    const { id } = req.params;
    const { title, type, price, ethPrice, address, description } = req.body;

    console.log('=== UPDATE PROPERTY DEBUG ===');
    console.log('Property ID:', id);
    console.log('Request body:', req.body);
    console.log('Request file:', req.file ? req.file.filename : 'No file');

    // Check if property exists
    const [existing] = await pool.query('SELECT * FROM property WHERE id_property = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Property tidak ditemukan' });
    }

    // Prepare update data with proper field validation
    const updateData = {
      title: title || existing[0].title,
      type: type || existing[0].type,
      address: address || existing[0].address,
      description: description || existing[0].description,
    };

    // Handle price updates with validation
    if (price !== undefined && price !== null && price !== '') {
      const parsedPrice = parseFloat(price.toString().replace(/[^0-9.]/g, ''));
      if (isNaN(parsedPrice) || parsedPrice <= 0) {
        return res.status(400).json({ 
          success: false, 
          message: 'Harga harus berupa angka yang valid dan lebih besar dari 0' 
        });
      }
      updateData.price = parsedPrice;
    } else {
      updateData.price = existing[0].price;
    }

    // Handle ETH price updates with validation
    if (ethPrice !== undefined && ethPrice !== null && ethPrice !== '') {
      const parsedEthPrice = parseFloat(ethPrice.toString().replace(/[^0-9.]/g, ''));
      if (isNaN(parsedEthPrice) || parsedEthPrice <= 0) {
        return res.status(400).json({ 
          success: false, 
          message: 'Harga ETH harus berupa angka yang valid dan lebih besar dari 0' 
        });
      }
      updateData.ethPrice = parsedEthPrice;
    } else {
      updateData.ethPrice = existing[0].ethPrice;
    }

    // Handle image update
    if (req.file) {
      updateData.image = req.file.filename;
      
      // Optionally delete old image file if it exists
      if (existing[0].image && !existing[0].image.startsWith('http')) {
        const oldImagePath = path.join(__dirname, 'uploads', existing[0].image);
        if (fs.existsSync(oldImagePath)) {
          try {
            fs.unlinkSync(oldImagePath);
            console.log('Old image deleted:', existing[0].image);
          } catch (err) {
            console.warn('Failed to delete old image:', err.message);
          }
        }
      }
    }

    console.log('Update data:', updateData);

    // Update the property
    const [result] = await pool.query('UPDATE property SET ? WHERE id_property = ?', [updateData, id]);
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ success: false, message: 'Property tidak ditemukan' });
    }

    // Get updated property data
    const [updated] = await pool.query('SELECT * FROM property WHERE id_property = ?', [id]);
    const updatedProperty = {
      ...updated[0],
      image: updated[0].image?.startsWith('http') 
        ? updated[0].image 
        : updated[0].image 
          ? `${req.protocol}://${req.get('host')}/uploads/${updated[0].image}`
          : null
    };

    console.log('Property updated successfully:', id);

    res.json({ 
      success: true, 
      message: 'Property berhasil diperbarui',
      data: updatedProperty
    });

  } catch (err) {
    console.error('=== UPDATE PROPERTY ERROR ===');
    console.error('Error details:', err);
    console.error('Stack trace:', err.stack);
    
    // Handle specific database errors
    if (err.code === 'ER_BAD_FIELD_ERROR') {
      return res.status(500).json({ 
        success: false, 
        message: 'Field database tidak sesuai. Periksa struktur tabel property.' 
      });
    }
    
    res.status(500).json({ 
      success: false, 
      message: 'Gagal memperbarui property',
      error: process.env.NODE_ENV === 'development' ? err.message : 'Internal server error'
    });
  }
});
// --- Delete Property
app.delete('/api/properties/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    const [existing] = await pool.query('SELECT * FROM property WHERE id_property = ?', [id]);
    if (existing.length === 0) {
      return res.status(404).json({ success: false, message: 'Property tidak ditemukan' });
    }

    await pool.query('DELETE FROM property WHERE id_property = ?', [id]);

    res.json({ success: true, message: 'Property berhasil dihapus' });
  } catch (err) {
    console.error('Error deleting property:', err.message);
    res.status(500).json({ success: false, message: 'Gagal menghapus property' });
  }
});

// --- Get All Transactions
app.get('/api/transactions', async (req, res) => {
  try {
    const [transactions] = await pool.query(`
      SELECT t.*, p.title AS property_title, p.image AS property_image
      FROM transaksi t
      LEFT JOIN property p ON t.Property_id = p.id_property
      ORDER BY t.Id_transaksi DESC
    `);
    res.json({ success: true, data: transactions });
  } catch (err) {
    console.error('Error fetching transactions:', err.message);
    res.status(500).json({ success: false, message: 'Gagal mengambil transaksi' });
  }
});

// --- Get Dashboard Statistics
app.get('/api/dashboard/stats', async (req, res) => {
  try {
    // Get total properties
    const [propertiesCount] = await pool.query('SELECT COUNT(*) as total FROM property');
    
    // Get total transactions
    const [transactionsCount] = await pool.query('SELECT COUNT(*) as total FROM transaksi');
    
    // Get total ETH amount
    const [ethSum] = await pool.query('SELECT SUM(eth_amount) as total FROM transaksi WHERE status = "Completed"');
    
    // Get pending transactions
    const [pendingCount] = await pool.query('SELECT COUNT(*) as total FROM transaksi WHERE status = "Pending"');
    
    // Get recent transactions
    const [recentTransactions] = await pool.query(`
      SELECT t.*, p.title AS property_title
      FROM transaksi t
      LEFT JOIN property p ON t.Property_id = p.id_property
      ORDER BY t.created_at DESC
      LIMIT 5
    `);

    const stats = {
      totalProperties: propertiesCount[0].total,
      totalTransactions: transactionsCount[0].total,
      totalEth: ethSum[0].total || 0,
      pendingTransactions: pendingCount[0].total,
      recentTransactions: recentTransactions
    };

    res.json({ success: true, data: stats });
  } catch (err) {
    console.error('Error fetching dashboard stats:', err.message);
    res.status(500).json({ success: false, message: 'Gagal mengambil statistik dashboard' });
  }
});

// --- Simpan Transaksi Baru
app.post('/api/transactions', async (req, res) => {
  try {
    const { name, email, phone, property_id, ethAmount, txHash, user_id } = req.body;
    const required = ['name', 'email', 'property_id', 'ethAmount', 'txHash'];
    const missing = required.filter(field => !req.body[field]);

    if (missing.length > 0) {
      return res.status(400).json({ success: false, message: 'Field berikut wajib diisi', missing });
    }

    const [result] = await pool.query('INSERT INTO transaksi SET ?', {
      User_id: user_id,
      Property_id: property_id,
      name,
      email,
      phone: phone || null,
      eth_amount: ethAmount,
      tx_hash: txHash,
      status: 'Completed',
      created_at: new Date()
    });

    res.status(201).json({ success: true, message: 'Transaksi berhasil disimpan', transactionId: result.insertId });
  } catch (err) {
    console.error('Error saving transaction:', err.message);
    res.status(500).json({ success: false, message: 'Gagal menyimpan transaksi', error: err.message });
  }
});

app.post('/api/register', async (req, res) => {
  try {
    const { name, email, password } = req.body;
    
    console.log('=== REGISTER DEBUG ===');
    console.log('Input data:', { 
      name, 
      email, 
      password: password ? `${password.length} chars` : 'null' 
    });
    
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Semua field wajib diisi' });
    }

    // Check existing user
    const [existing] = await pool.query('SELECT * FROM admin WHERE email = ?', [email]);
    if (existing.length > 0) {
      return res.status(400).json({ success: false, message: 'Email sudah digunakan' });
    }

    // Hash password
    console.log('Original password length:', password.length);
    const hashedPassword = await bcrypt.hash(password, 10);
    console.log('Hashed password length:', hashedPassword.length);
    console.log('Hash preview:', hashedPassword.substring(0, 30) + '...');

    const userData = {
      name,
      email,
      password: hashedPassword, 
      Created_at: new Date()
    };

    console.log('Data to insert:', {
      name: userData.name,
      email: userData.email,
      passwordLength: userData.password.length
    });

    const [result] = await pool.query('INSERT INTO admin SET ?', userData);
    console.log('Insert result ID:', result.insertId);

    // Verify stored data
    const [verify] = await pool.query('SELECT Password FROM admin WHERE id = ?', [result.insertId]);
    console.log('Stored password length:', verify[0]?.password?.length);
    console.log('Storage verification passed:', verify[0]?.password === hashedPassword);

    res.status(201).json({ 
      success: true, 
      message: 'Registrasi berhasil', 
      userId: result.insertId 
    });
  } catch (err) {
    console.error('Register error details:', err);
    res.status(500).json({ 
      success: false, 
      message: 'Gagal registrasi', 
      error: err.message 
    });
  }
});

// --- Login User (dengan debug lengkap)
app.post('/api/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    
    console.log('=== LOGIN DEBUG ===');
    console.log('Login attempt:', { 
      email, 
      passwordLength: password ? password.length : 0 
    });
    
    if (!email || !password) {
      return res.status(400).json({ success: false, error: 'Email dan password wajib diisi' });
    }

    // Query dengan nama kolom yang benar (Password dengan huruf kapital)
    const [rows] = await pool.query('SELECT * FROM admin WHERE email = ?', [email]);
    
    if (rows.length === 0) {
      console.log('User not found for email:', email);
      return res.status(401).json({ success: false, error: 'Email tidak ditemukan' });
    }

    const user = rows[0];
    console.log('User data retrieved:', {
      id: user.id,
      name: user.name,
      email: user.email,
      hasPassword: !!user.password, // PENTING: Gunakan 'Password' dengan huruf kapital
      passwordType: typeof user.password,
      passwordLength: user.password ? user.password.length : 0,
      passwordPreview: user.Password ? user.password.substring(0, 20) + '...' : 'null'
    });

    // Validasi password hash
    if (!user.password || typeof user.password !== 'string') {
      console.error('CRITICAL: Invalid password hash detected!');
      console.error('Password value:', user.password);
      console.error('Password type:', typeof user.password);
      return res.status(500).json({ 
        success: false, 
        error: 'Password hash tidak valid - data corrupted' 
      });
    }

    console.log('About to compare passwords...');
    console.log('Input password length:', password.length);
    console.log('Stored hash length:', user.password.length);
    
    // Compare passwords
    const isMatch = await bcrypt.compare(password, user.password);
    console.log('Password comparison result:', isMatch);

    if (!isMatch) {
      console.log('Password mismatch - login failed');
      return res.status(401).json({ success: false, error: 'Password salah' });
    }

    // Generate JWT token
    const token = jwt.sign(
      { 
        id: user.id, 
        email: user.email, 
        name: user.name 
      },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    // Remove password from response
    const { Password, ...userWithoutPassword } = user;

    console.log('Login successful!');
    res.json({ 
      success: true, 
      message: 'Login berhasil', 
      user: userWithoutPassword,
      token: token
    });
  } catch (err) {
    console.error('Login error details:', err);
    res.status(500).json({ 
      success: false, 
      error: 'Gagal login', 
      detail: err.message 
    });
  }
});

// --- Get User Profile (Protected Route)
app.get('/api/user/profile', authenticateToken, async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, name, email, created_at FROM admin WHERE id = ?', [req.user.id]);
    
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User tidak ditemukan' });
    }

    res.json({ success: true, data: rows[0] });
  } catch (err) {
    console.error('Get profile error:', err.message);
    res.status(500).json({ success: false, error: 'Gagal mengambil profile' });
  }
});

// === Global Error Handler ===
app.use((err, req, res, next) => {
  console.error('Server error:', err.message);
  
  if (err instanceof multer.MulterError) {
    if (err.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ success: false, message: 'File terlalu besar (maksimal 5MB)' });
    }
  }
  
  res.status(500).json({ success: false, message: 'Internal Server Error' });
});

// === Jalankan Server ===
async function startServer() {
  try {
    const conn = await pool.getConnection();
    await conn.ping();
    conn.release();

    app.listen(PORT, '0.0.0.0', () => {
      console.log(`Server berjalan di http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Gagal koneksi ke database:', err.message);
    process.exit(1);
  }
}

startServer();