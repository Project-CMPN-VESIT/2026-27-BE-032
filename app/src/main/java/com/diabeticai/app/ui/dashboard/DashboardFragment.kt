package com.diabeticai.app.ui.dashboard

import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import androidx.fragment.app.Fragment
import androidx.fragment.app.viewModels
import androidx.navigation.fragment.findNavController
import com.diabeticai.app.R
import com.diabeticai.app.databinding.FragmentDashboardBinding

class DashboardFragment : Fragment() {

    private var _binding: FragmentDashboardBinding? = null
    private val binding get() = _binding!!
    private val viewModel: DashboardViewModel by viewModels()

    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View {
        _binding = FragmentDashboardBinding.inflate(inflater, container, false)
        return binding.root
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        viewModel.userData.observe(viewLifecycleOwner) { user ->
            binding.tvUserName.text = user.name
        }

        // Service Grid Click Listeners
        binding.cardServiceFoot.setOnClickListener {
            findNavController().navigate(R.id.action_dashboard_to_foot)
        }

        binding.cardServiceRetina.setOnClickListener {
            findNavController().navigate(R.id.action_dashboard_to_eye)
        }

        binding.cardServiceAssessment.setOnClickListener {
            findNavController().navigate(R.id.action_dashboard_to_assessment)
        }

        binding.cardServiceCare.setOnClickListener {
            findNavController().navigate(R.id.action_dashboard_to_care)
        }
    }

    override fun onDestroyView() {
        super.onDestroyView()
        _binding = null
    }
}
