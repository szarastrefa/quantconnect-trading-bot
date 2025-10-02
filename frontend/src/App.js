import React, { useState, useEffect, useContext, createContext } from 'react';
import {
  ThemeProvider,
  createTheme,
  CssBaseline,
  AppBar,
  Toolbar,
  Typography,
  Container,
  Grid,
  Card,
  CardContent,
  Button,
  TextField,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Snackbar,
  Alert,
  Switch,
  FormControlLabel,
  Tabs,
  Tab,
  Box,
  Chip,
  List,
  ListItem,
  ListItemText,
  ListItemIcon,
  IconButton,
  Badge,
  LinearProgress,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
} from '@mui/material';
import {
  TrendingUp,
  TrendingDown,
  AccountBalance,
  Settings,
  PlayArrow,
  Stop,
  Refresh,
  CloudUpload,
  Notifications,
  Dashboard,
  BarChart,
  Psychology,
  Link as LinkIcon,
  LinkOff,
  Circle,
} from '@mui/icons-material';
import { Line } from 'react-chartjs-2';
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler,
} from 'chart.js';
import axios from 'axios';
import io from 'socket.io-client';
import { Formik, Form, Field } from 'formik';
import * as Yup from 'yup';

// Register Chart.js components
ChartJS.register(
  CategoryScale,
  LinearScale,
  PointElement,
  LineElement,
  Title,
  Tooltip,
  Legend,
  Filler
);

// Context for global state management
const TradingContext = createContext();

// Configuration
const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:5000/api';
const WS_URL = process.env.REACT_APP_WS_URL || 'ws://localhost:5000';

// Custom hook for trading context
const useTradingContext = () => {
  const context = useContext(TradingContext);
  if (!context) {
    throw new Error('useTradingContext must be used within TradingProvider');
  }
  return context;
};

// Trading Provider Component
const TradingProvider = ({ children }) => {
  const [state, setState] = useState({
    // Connection status
    isConnected: false,
    tradingActive: false,
    
    // Market data
    marketData: {},
    signals: {},
    
    // Brokers
    brokers: [],
    connectedBrokers: [],
    
    // ML Models
    mlModels: [],
    
    // Trading session
    currentSession: null,
    positions: [],
    
    // UI state
    notifications: [],
    loading: false,
  });
  
  const [socket, setSocket] = useState(null);
  
  // Initialize WebSocket connection
  useEffect(() => {
    const newSocket = io(WS_URL);
    setSocket(newSocket);
    
    newSocket.on('connect', () => {
      setState(prev => ({ ...prev, isConnected: true }));
      addNotification('Connected to trading server', 'success');
    });
    
    newSocket.on('disconnect', () => {
      setState(prev => ({ ...prev, isConnected: false }));
      addNotification('Disconnected from server', 'error');
    });
    
    newSocket.on('market_data_update', (data) => {
      setState(prev => ({
        ...prev,
        marketData: { ...prev.marketData, ...data.data }
      }));
    });
    
    newSocket.on('signals_update', (data) => {
      setState(prev => ({
        ...prev,
        signals: data.signals,
        marketData: { ...prev.marketData, ...data.market_data }
      }));
    });
    
    newSocket.on('trading_status', (data) => {
      setState(prev => ({
        ...prev,
        tradingActive: data.active,
        currentSession: data.session_id || null
      }));
    });
    
    newSocket.on('trading_error', (data) => {
      addNotification(`Trading Error: ${data.message}`, 'error');
    });
    
    return () => newSocket.close();
  }, []);
  
  // Load initial data
  useEffect(() => {
    loadBrokers();
    loadMLModels();
    loadPositions();
  }, []);
  
  const addNotification = (message, severity = 'info') => {
    const notification = {
      id: Date.now(),
      message,
      severity,
      timestamp: new Date().toISOString()
    };
    setState(prev => ({
      ...prev,
      notifications: [notification, ...prev.notifications.slice(0, 9)]
    }));
  };
  
  const loadBrokers = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/brokers`);
      setState(prev => ({ ...prev, brokers: response.data.brokers || [] }));
    } catch (error) {
      addNotification('Failed to load brokers', 'error');
    }
  };
  
  const loadMLModels = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/models`);
      setState(prev => ({ ...prev, mlModels: response.data.models || [] }));
    } catch (error) {
      addNotification('Failed to load ML models', 'error');
    }
  };
  
  const loadPositions = async () => {
    try {
      const response = await axios.get(`${API_BASE_URL}/trading/positions`);
      setState(prev => ({ ...prev, positions: response.data.positions || [] }));
    } catch (error) {
      console.error('Failed to load positions:', error);
    }
  };
  
  const startTrading = (config) => {
    if (socket) {
      socket.emit('start_trading', { strategy_config: config });
      setState(prev => ({ ...prev, loading: true }));
    }
  };
  
  const stopTrading = () => {
    if (socket) {
      socket.emit('stop_trading');
      setState(prev => ({ ...prev, loading: true }));
    }
  };
  
  const connectBroker = async (brokerName, config) => {
    try {
      const response = await axios.post(`${API_BASE_URL}/brokers/${brokerName}/connect`, config);
      if (response.data.success) {
        setState(prev => ({
          ...prev,
          connectedBrokers: [...prev.connectedBrokers, brokerName]
        }));
        addNotification(`Connected to ${brokerName}`, 'success');
        return true;
      }
      return false;
    } catch (error) {
      addNotification(`Failed to connect to ${brokerName}: ${error.message}`, 'error');
      return false;
    }
  };
  
  const getMarketData = (symbols) => {
    if (socket) {
      socket.emit('get_market_data', { symbols });
    }
  };
  
  const uploadMLModel = async (file, modelInfo) => {
    try {
      const formData = new FormData();
      formData.append('model_file', file);
      formData.append('model_info', JSON.stringify(modelInfo));
      
      const response = await axios.post(`${API_BASE_URL}/models/import`, formData, {
        headers: { 'Content-Type': 'multipart/form-data' }
      });
      
      if (response.data.success) {
        loadMLModels();
        addNotification('ML Model uploaded successfully', 'success');
        return true;
      }
      return false;
    } catch (error) {
      addNotification(`Failed to upload model: ${error.message}`, 'error');
      return false;
    }
  };
  
  const value = {
    ...state,
    addNotification,
    startTrading,
    stopTrading,
    connectBroker,
    getMarketData,
    uploadMLModel,
    loadBrokers,
    loadMLModels,
    loadPositions,
  };
  
  return (
    <TradingContext.Provider value={value}>
      {children}
    </TradingContext.Provider>
  );
};

// Dashboard Component
const Dashboard = () => {
  const {
    marketData,
    signals,
    positions,
    connectedBrokers,
    mlModels,
    tradingActive,
    isConnected
  } = useTradingContext();
  
  // Calculate portfolio metrics
  const totalPnL = positions.reduce((sum, pos) => sum + (pos.unrealized_pnl || 0), 0);
  const totalValue = positions.reduce((sum, pos) => sum + (pos.market_value || 0), 0);
  const signalCount = Object.keys(signals).length;
  
  // Prepare chart data
  const chartData = {
    labels: Object.keys(marketData).slice(0, 10),
    datasets: [
      {
        label: 'Price',
        data: Object.values(marketData).slice(0, 10).map(d => d.price || 0),
        borderColor: 'rgb(75, 192, 192)',
        backgroundColor: 'rgba(75, 192, 192, 0.2)',
        fill: true,
      }
    ],
  };
  
  return (
    <Grid container spacing={3}>
      {/* Status Cards */}
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <AccountBalance color="primary" />
              <Box ml={2}>
                <Typography variant="h6">
                  ${totalValue.toLocaleString()}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Portfolio Value
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              {totalPnL >= 0 ? <TrendingUp color="success" /> : <TrendingDown color="error" />}
              <Box ml={2}>
                <Typography variant="h6" color={totalPnL >= 0 ? 'success.main' : 'error.main'}>
                  ${totalPnL.toLocaleString()}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Unrealized P&L
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <BarChart color="info" />
              <Box ml={2}>
                <Typography variant="h6">
                  {signalCount}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Active Signals
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      
      <Grid item xs={12} sm={6} md={3}>
        <Card>
          <CardContent>
            <Box display="flex" alignItems="center">
              <LinkIcon color={isConnected ? 'success' : 'error'} />
              <Box ml={2}>
                <Typography variant="h6">
                  {connectedBrokers.length}
                </Typography>
                <Typography variant="body2" color="textSecondary">
                  Connected Brokers
                </Typography>
              </Box>
            </Box>
          </CardContent>
        </Card>
      </Grid>
      
      {/* Market Data Chart */}
      <Grid item xs={12} md={8}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Market Data
            </Typography>
            <Box height={300}>
              <Line
                data={chartData}
                options={{
                  responsive: true,
                  maintainAspectRatio: false,
                  plugins: {
                    legend: {
                      position: 'top',
                    },
                    title: {
                      display: true,
                      text: 'Real-time Price Data',
                    },
                  },
                }}
              />
            </Box>
          </CardContent>
        </Card>
      </Grid>
      
      {/* Trading Signals */}
      <Grid item xs={12} md={4}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Trading Signals
            </Typography>
            <List>
              {Object.entries(signals).slice(0, 5).map(([symbol, signal]) => (
                <ListItem key={symbol}>
                  <ListItemIcon>
                    {signal.type === 'buy' ? (
                      <TrendingUp color="success" />
                    ) : (
                      <TrendingDown color="error" />
                    )}
                  </ListItemIcon>
                  <ListItemText
                    primary={symbol}
                    secondary={`${signal.type?.toUpperCase()} - Confidence: ${(signal.confidence * 100).toFixed(1)}%`}
                  />
                  <Chip
                    label={signal.strength || 'N/A'}
                    size="small"
                    color={signal.strength > 0.7 ? 'success' : signal.strength > 0.4 ? 'warning' : 'default'}
                  />
                </ListItem>
              ))}
            </List>
          </CardContent>
        </Card>
      </Grid>
      
      {/* Active Positions */}
      <Grid item xs={12}>
        <Card>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              Active Positions
            </Typography>
            <TableContainer>
              <Table>
                <TableHead>
                  <TableRow>
                    <TableCell>Symbol</TableCell>
                    <TableCell>Side</TableCell>
                    <TableCell align="right">Quantity</TableCell>
                    <TableCell align="right">Entry Price</TableCell>
                    <TableCell align="right">Current Price</TableCell>
                    <TableCell align="right">Unrealized P&L</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {positions.map((position, index) => (
                    <TableRow key={index}>
                      <TableCell>{position.symbol}</TableCell>
                      <TableCell>
                        <Chip
                          label={position.side}
                          color={position.side === 'buy' ? 'success' : 'error'}
                          size="small"
                        />
                      </TableCell>
                      <TableCell align="right">{position.quantity}</TableCell>
                      <TableCell align="right">${position.entry_price?.toFixed(4)}</TableCell>
                      <TableCell align="right">${position.current_price?.toFixed(4)}</TableCell>
                      <TableCell
                        align="right"
                        sx={{
                          color: (position.unrealized_pnl || 0) >= 0 ? 'success.main' : 'error.main'
                        }}
                      >
                        ${(position.unrealized_pnl || 0).toFixed(2)}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent>
        </Card>
      </Grid>
    </Grid>
  );
};

// Broker Management Component
const BrokerManagement = () => {
  const { brokers, connectedBrokers, connectBroker } = useTradingContext();
  const [selectedBroker, setSelectedBroker] = useState(null);
  const [configDialog, setConfigDialog] = useState(false);
  
  const brokerSchema = Yup.object().shape({
    api_key: Yup.string().required('API Key is required'),
    secret_key: Yup.string().required('Secret Key is required'),
    testnet: Yup.boolean(),
  });
  
  const handleConnectBroker = async (values) => {
    const success = await connectBroker(selectedBroker.name, values);
    if (success) {
      setConfigDialog(false);
      setSelectedBroker(null);
    }
  };
  
  return (
    <Container maxWidth="lg">
      <Typography variant="h4" gutterBottom>
        Broker Management
      </Typography>
      
      <Grid container spacing={3}>
        {brokers.map((broker) => {
          const isConnected = connectedBrokers.includes(broker.name);
          
          return (
            <Grid item xs={12} sm={6} md={4} key={broker.name}>
              <Card>
                <CardContent>
                  <Box display="flex" alignItems="center" justifyContent="space-between">
                    <Box>
                      <Typography variant="h6">{broker.name}</Typography>
                      <Typography variant="body2" color="textSecondary">
                        {broker.type} • {broker.asset_classes?.join(', ')}
                      </Typography>
                    </Box>
                    <Circle color={isConnected ? 'success' : 'disabled'} />
                  </Box>
                  
                  <Box mt={2}>
                    <Button
                      variant={isConnected ? 'outlined' : 'contained'}
                      color={isConnected ? 'success' : 'primary'}
                      fullWidth
                      disabled={isConnected}
                      onClick={() => {
                        setSelectedBroker(broker);
                        setConfigDialog(true);
                      }}
                      startIcon={isConnected ? <LinkIcon /> : <LinkOff />}
                    >
                      {isConnected ? 'Connected' : 'Connect'}
                    </Button>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          );
        })}
      </Grid>
      
      {/* Broker Configuration Dialog */}
      <Dialog open={configDialog} onClose={() => setConfigDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>
          Configure {selectedBroker?.name}
        </DialogTitle>
        <Formik
          initialValues={{
            api_key: '',
            secret_key: '',
            testnet: true,
          }}
          validationSchema={brokerSchema}
          onSubmit={handleConnectBroker}
        >
          {({ errors, touched, values, setFieldValue, isSubmitting }) => (
            <Form>
              <DialogContent>
                <Grid container spacing={2}>
                  <Grid item xs={12}>
                    <Field
                      name="api_key"
                      as={TextField}
                      label="API Key"
                      fullWidth
                      error={touched.api_key && errors.api_key}
                      helperText={touched.api_key && errors.api_key}
                    />
                  </Grid>
                  <Grid item xs={12}>
                    <Field
                      name="secret_key"
                      as={TextField}
                      label="Secret Key"
                      type="password"
                      fullWidth
                      error={touched.secret_key && errors.secret_key}
                      helperText={touched.secret_key && errors.secret_key}
                    />
                  </Grid>
                  <Grid item xs={12}>
                    <FormControlLabel
                      control={
                        <Switch
                          checked={values.testnet}
                          onChange={(e) => setFieldValue('testnet', e.target.checked)}
                        />
                      }
                      label="Use Testnet/Demo Account"
                    />
                  </Grid>
                </Grid>
              </DialogContent>
              <DialogActions>
                <Button onClick={() => setConfigDialog(false)}>
                  Cancel
                </Button>
                <Button type="submit" variant="contained" disabled={isSubmitting}>
                  Connect
                </Button>
              </DialogActions>
            </Form>
          )}
        </Formik>
      </Dialog>
    </Container>
  );
};

// ML Model Management Component
const MLModelManagement = () => {
  const { mlModels, uploadMLModel } = useTradingContext();
  const [uploadDialog, setUploadDialog] = useState(false);
  const [selectedFile, setSelectedFile] = useState(null);
  
  const handleFileUpload = (event) => {
    setSelectedFile(event.target.files[0]);
  };
  
  const handleModelUpload = async (values) => {
    if (selectedFile) {
      const success = await uploadMLModel(selectedFile, values);
      if (success) {
        setUploadDialog(false);
        setSelectedFile(null);
      }
    }
  };
  
  return (
    <Container maxWidth="lg">
      <Box display="flex" justifyContent="space-between" alignItems="center" mb={3}>
        <Typography variant="h4">
          ML Model Management
        </Typography>
        <Button
          variant="contained"
          startIcon={<CloudUpload />}
          onClick={() => setUploadDialog(true)}
        >
          Upload Model
        </Button>
      </Box>
      
      <Grid container spacing={3}>
        {mlModels.map((model, index) => (
          <Grid item xs={12} sm={6} md={4} key={index}>
            <Card>
              <CardContent>
                <Box display="flex" alignItems="center" mb={2}>
                  <Psychology color="primary" />
                  <Typography variant="h6" ml={1}>
                    {model.name}
                  </Typography>
                </Box>
                
                <Typography variant="body2" color="textSecondary" paragraph>
                  {model.description}
                </Typography>
                
                <Box display="flex" justifyContent="space-between" alignItems="center">
                  <Chip
                    label={model.status || 'Active'}
                    color={model.status === 'Active' ? 'success' : 'default'}
                    size="small"
                  />
                  <Typography variant="caption" color="textSecondary">
                    Accuracy: {model.accuracy ? `${(model.accuracy * 100).toFixed(1)}%` : 'N/A'}
                  </Typography>
                </Box>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
      
      {/* Model Upload Dialog */}
      <Dialog open={uploadDialog} onClose={() => setUploadDialog(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Upload ML Model</DialogTitle>
        <Formik
          initialValues={{
            name: '',
            description: '',
            model_type: 'classification',
          }}
          onSubmit={handleModelUpload}
        >
          {({ values, setFieldValue, isSubmitting }) => (
            <Form>
              <DialogContent>
                <Grid container spacing={2}>
                  <Grid item xs={12}>
                    <TextField
                      name="name"
                      label="Model Name"
                      fullWidth
                      value={values.name}
                      onChange={(e) => setFieldValue('name', e.target.value)}
                    />
                  </Grid>
                  <Grid item xs={12}>
                    <TextField
                      name="description"
                      label="Description"
                      multiline
                      rows={3}
                      fullWidth
                      value={values.description}
                      onChange={(e) => setFieldValue('description', e.target.value)}
                    />
                  </Grid>
                  <Grid item xs={12}>
                    <input
                      accept=".pkl,.joblib,.h5,.pt,.pth"
                      style={{ display: 'none' }}
                      id="model-file-upload"
                      type="file"
                      onChange={handleFileUpload}
                    />
                    <label htmlFor="model-file-upload">
                      <Button
                        variant="outlined"
                        component="span"
                        fullWidth
                        startIcon={<CloudUpload />}
                      >
                        {selectedFile ? selectedFile.name : 'Select Model File'}
                      </Button>
                    </label>
                  </Grid>
                </Grid>
              </DialogContent>
              <DialogActions>
                <Button onClick={() => setUploadDialog(false)}>
                  Cancel
                </Button>
                <Button
                  type="submit"
                  variant="contained"
                  disabled={isSubmitting || !selectedFile}
                >
                  Upload
                </Button>
              </DialogActions>
            </Form>
          )}
        </Formik>
      </Dialog>
    </Container>
  );
};

// Trading Control Component
const TradingControl = () => {
  const {
    tradingActive,
    connectedBrokers,
    mlModels,
    startTrading,
    stopTrading,
    getMarketData,
  } = useTradingContext();
  
  const [strategyConfig, setStrategyConfig] = useState({
    name: 'Default Strategy',
    symbols: ['EURUSD', 'GBPUSD', 'USDJPY'],
    strategy_type: 'ml_signals',
    use_ml: true,
    use_lean: true,
    brokers: [],
    interval: 60,
    max_iterations: 0,
  });
  
  const handleStartTrading = () => {
    startTrading(strategyConfig);
  };
  
  const handleStopTrading = () => {
    stopTrading();
  };
  
  const handleGetMarketData = () => {
    getMarketData(strategyConfig.symbols);
  };
  
  return (
    <Container maxWidth="lg">
      <Typography variant="h4" gutterBottom>
        Trading Control
      </Typography>
      
      <Grid container spacing={3}>
        {/* Strategy Configuration */}
        <Grid item xs={12} md={8}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Strategy Configuration
              </Typography>
              
              <Grid container spacing={2}>
                <Grid item xs={12} sm={6}>
                  <TextField
                    label="Strategy Name"
                    fullWidth
                    value={strategyConfig.name}
                    onChange={(e) => setStrategyConfig({
                      ...strategyConfig,
                      name: e.target.value
                    })}
                  />
                </Grid>
                
                <Grid item xs={12} sm={6}>
                  <TextField
                    label="Trading Interval (seconds)"
                    type="number"
                    fullWidth
                    value={strategyConfig.interval}
                    onChange={(e) => setStrategyConfig({
                      ...strategyConfig,
                      interval: parseInt(e.target.value)
                    })}
                  />
                </Grid>
                
                <Grid item xs={12}>
                  <TextField
                    label="Trading Symbols (comma-separated)"
                    fullWidth
                    value={strategyConfig.symbols.join(', ')}
                    onChange={(e) => setStrategyConfig({
                      ...strategyConfig,
                      symbols: e.target.value.split(',').map(s => s.trim())
                    })}
                  />
                </Grid>
                
                <Grid item xs={12} sm={6}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={strategyConfig.use_ml}
                        onChange={(e) => setStrategyConfig({
                          ...strategyConfig,
                          use_ml: e.target.checked
                        })}
                      />
                    }
                    label="Use ML Models"
                  />
                </Grid>
                
                <Grid item xs={12} sm={6}>
                  <FormControlLabel
                    control={
                      <Switch
                        checked={strategyConfig.use_lean}
                        onChange={(e) => setStrategyConfig({
                          ...strategyConfig,
                          use_lean: e.target.checked
                        })}
                      />
                    }
                    label="Use QuantConnect Lean"
                  />
                </Grid>
              </Grid>
            </CardContent>
          </Card>
        </Grid>
        
        {/* Control Panel */}
        <Grid item xs={12} md={4}>
          <Card>
            <CardContent>
              <Typography variant="h6" gutterBottom>
                Control Panel
              </Typography>
              
              <Box display="flex" flexDirection="column" gap={2}>
                <Button
                  variant="contained"
                  color={tradingActive ? 'error' : 'success'}
                  size="large"
                  fullWidth
                  onClick={tradingActive ? handleStopTrading : handleStartTrading}
                  startIcon={tradingActive ? <Stop /> : <PlayArrow />}
                  disabled={connectedBrokers.length === 0}
                >
                  {tradingActive ? 'Stop Trading' : 'Start Trading'}
                </Button>
                
                <Button
                  variant="outlined"
                  fullWidth
                  onClick={handleGetMarketData}
                  startIcon={<Refresh />}
                >
                  Refresh Market Data
                </Button>
                
                <Box mt={2}>
                  <Typography variant="body2" color="textSecondary">
                    Connected Brokers: {connectedBrokers.length}
                  </Typography>
                  <Typography variant="body2" color="textSecondary">
                    Active Models: {mlModels.filter(m => m.status === 'Active').length}
                  </Typography>
                </Box>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Container>
  );
};

// Main App Component
const App = () => {
  const [darkMode, setDarkMode] = useState(false);
  const [currentTab, setCurrentTab] = useState(0);
  const [notifications, setNotifications] = useState([]);
  
  const theme = createTheme({
    palette: {
      mode: darkMode ? 'dark' : 'light',
      primary: {
        main: '#1976d2',
      },
      success: {
        main: '#2e7d32',
      },
      error: {
        main: '#d32f2f',
      },
    },
  });
  
  const TabPanel = ({ children, value, index, ...other }) => {
    return (
      <div
        role="tabpanel"
        hidden={value !== index}
        {...other}
      >
        {value === index && (
          <Box sx={{ p: 3 }}>
            {children}
          </Box>
        )}
      </div>
    );
  };
  
  return (
    <ThemeProvider theme={theme}>
      <CssBaseline />
      <TradingProvider>
        <div className="App">
          <AppBar position="sticky">
            <Toolbar>
              <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
                QuantConnect Trading Bot
              </Typography>
              
              <FormControlLabel
                control={
                  <Switch
                    checked={darkMode}
                    onChange={(e) => setDarkMode(e.target.checked)}
                  />
                }
                label="Dark Mode"
                sx={{ color: 'inherit' }}
              />
              
              <IconButton color="inherit">
                <Badge badgeContent={notifications.length} color="error">
                  <Notifications />
                </Badge>
              </IconButton>
            </Toolbar>
            
            <Tabs
              value={currentTab}
              onChange={(event, newValue) => setCurrentTab(newValue)}
              centered
            >
              <Tab label="Dashboard" icon={<Dashboard />} />
              <Tab label="Trading" icon={<TrendingUp />} />
              <Tab label="Brokers" icon={<AccountBalance />} />
              <Tab label="ML Models" icon={<Psychology />} />
            </Tabs>
          </AppBar>
          
          <TabPanel value={currentTab} index={0}>
            <Dashboard />
          </TabPanel>
          <TabPanel value={currentTab} index={1}>
            <TradingControl />
          </TabPanel>
          <TabPanel value={currentTab} index={2}>
            <BrokerManagement />
          </TabPanel>
          <TabPanel value={currentTab} index={3}>
            <MLModelManagement />
          </TabPanel>
          
          {/* Notification System */}
          <TradingContext.Consumer>
            {({ notifications }) => (
              <>
                {notifications.slice(0, 1).map((notification) => (
                  <Snackbar
                    key={notification.id}
                    open={true}
                    autoHideDuration={6000}
                    anchorOrigin={{ vertical: 'bottom', horizontal: 'right' }}
                  >
                    <Alert
                      severity={notification.severity}
                      onClose={() => {}}
                    >
                      {notification.message}
                    </Alert>
                  </Snackbar>
                ))}
              </>
            )}
          </TradingContext.Consumer>
        </div>
      </TradingProvider>
    </ThemeProvider>
  );
};

export default App;