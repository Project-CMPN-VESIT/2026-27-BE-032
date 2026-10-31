package com.diabeticai.app.ui

import android.os.Bundle
import android.view.View
import androidx.appcompat.app.AppCompatActivity
import androidx.navigation.NavController
import androidx.navigation.fragment.NavHostFragment
import androidx.navigation.ui.setupWithNavController
import com.diabeticai.app.R
import com.diabeticai.app.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var navController: NavController

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val navHostFragment = supportFragmentManager
            .findFragmentById(R.id.nav_host_fragment) as NavHostFragment
        navController = navHostFragment.navController

        binding.bottomNavigation.setupWithNavController(navController)

        // Show/hide Header, Footer, and Bottom Nav based on active screen destination
        navController.addOnDestinationChangedListener { _, destination, _ ->
            when (destination.id) {
                R.id.splashFragment -> {
                    binding.headerView.root.visibility = View.GONE
                    binding.footerContainer.visibility = View.GONE
                }
                R.id.loginFragment, R.id.registerFragment -> {
                    binding.headerView.root.visibility = View.VISIBLE
                    binding.footerView.root.visibility = View.VISIBLE
                    binding.cardBottomNav.visibility = View.GONE
                }
                else -> {
                    binding.headerView.root.visibility = View.VISIBLE
                    binding.footerView.root.visibility = View.VISIBLE
                    binding.cardBottomNav.visibility = View.VISIBLE
                }
            }
        }
    }
}
