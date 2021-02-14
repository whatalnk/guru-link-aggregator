module.exports = {
    publicPath: process.env.NODE_ENV === 'production'
        ? '/guru-link-aggregator/'
        : '/',
    outputDir: 'docs',
    configureWebpack: {
        devServer: {
            watchOptions: {
                poll: true
            }
        }
    }
}