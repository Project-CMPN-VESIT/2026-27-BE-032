package com.diabeticai.app.ui.login

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.Toast
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.navigation.fragment.findNavController
import com.diabeticai.app.R
import com.diabeticai.app.databinding.FragmentRegisterBinding

class RegisterFragment : Fragment() {

    private var _binding: FragmentRegisterBinding? = null
    private val binding get() = _binding!!
    private val viewModel: AuthViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentRegisterBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.btnRegister.setOnClickListener {
            val name = binding.etRegisterName.text?.toString() ?: ""
            val email = binding.etRegisterEmail.text?.toString() ?: ""
            val pass = binding.etRegisterPassword.text?.toString() ?: ""

            if (name.isBlank() || email.isBlank() || pass.isBlank()) {
                Toast.makeText(requireContext(), "Please fill in all registration fields", Toast.LENGTH_SHORT).show()
            } else {
                viewModel.register(name, email, pass)
            }
        }

        binding.btnGoLogin.setOnClickListener {
            findNavController().navigate(R.id.action_register_to_login)
        }

        viewModel.loginState.observe(viewLifecycleOwner) { success ->
            if (success) {
                findNavController().navigate(R.id.action_register_to_dashboard)
            }
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
