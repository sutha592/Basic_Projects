🔍 Overview Description:

This Python script is a Streamlit-based web application developed for stock forecasting and sentiment analysis. It enables users to select a stock from a predefined list and view its historical data, including moving averages and volatility trends. Using the Prophet library, the app generates future stock price predictions, providing interactive visualizations for better insight. It also incorporates sentiment analysis by evaluating recent news headlines related to the selected stock using NLTK’s VADER sentiment analyzer. Users can conveniently download the forecast results in CSV or PDF formats. Designed with an intuitive interface, the application is ideal for casual investors, financial analysts, and students seeking to explore and forecast stock market trends using real-time data.


📚 Libraries Used

The script utilizes several powerful Python libraries, each serving a specific purpose to enhance the application's functionality. **Streamlit** is used to build the interactive web application interface, while **datetime** manages date and time operations. **yfinance** is employed to fetch real-time stock market data and related news. For forecasting future stock prices, the **Prophet** library is integrated to perform time series analysis. Interactive visualizations and charts are created using **Plotly**, and data handling is efficiently managed through **Pandas**. To perform sentiment analysis on news headlines, the script uses **NLTK’s VADER** tool. Additionally, **FPDF** is utilized to generate comprehensive downloadable PDF reports. Temporary files for these reports are handled using **tempfile** and **os** libraries. Together, these libraries form the backbone of a robust and user-friendly financial analysis tool.


👤 Useful For Users Who

This application is especially useful for users who want to forecast stock prices without writing any code. It caters to those who need interactive visualizations to analyze time series stock data and are interested in basic technical analysis, such as moving averages and historical volatility. Additionally, it benefits users who seek sentiment analysis on stock-related news headlines to understand market sentiment. The app also appeals to individuals who prefer ready-to-download reports in CSV or PDF formats for offline review, reporting, or presentations, making it an ideal tool for investors, analysts, and finance enthusiasts.


✅ Key Features

The application offers several powerful features to enhance the user experience. It provides 📈 stock price forecasting using the Prophet model for up to four years, allowing users to anticipate future market trends. It also delivers 📰 sentiment insights by analyzing current news headlines related to the selected stock, helping users gauge market mood. Users can explore 📉 interactive charts that display price movements, forecast components, and a sentiment distribution pie chart for a comprehensive visual analysis. Additionally, the app supports 🧾 PDF report generation, which includes company information, a summary of recent news, sentiment analysis results, and a detailed forecast table—making it a complete tool for informed financial decision-making.

